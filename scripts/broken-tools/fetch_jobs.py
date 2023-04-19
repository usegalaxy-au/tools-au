#!/usr/bin/env python3

"""Read in broken tools data from remote PG database and filter data."""

import os
import argparse
import psycopg2
import pandas as pd
from datetime import datetime
from dotenv import load_dotenv
from sshtunnel import SSHTunnelForwarder

load_dotenv()

DEFAULT_OUTFILE = 'tool_status_flat.csv'
DATABASE = {
    'database': os.environ.get('GALAXY_PG_DATABASE'),
    'table': os.environ.get('GALAXY_PG_JOB_TABLE'),
    'user': os.environ.get('GALAXY_PG_USER'),
    'password': os.environ.get('GALAXY_PG_PASSWORD'),
    'host': os.environ.get('GALAXY_PG_HOST'),
    'port': int(os.environ.get('GALAXY_PG_PORT')),
    'ssh_key': os.environ.get('GALAXY_PG_SSH_KEY'),
    'ssh_username': os.environ.get('GALAXY_PG_SSH_USERNAME'),
}
COLUMNS = [
    'create_time',
    'tool_id',
    'tool_version',
    'user_id',
    'session_id',
    'command_line',
    'params',
    'info',
    'state',
    'tool_stdout',
    'tool_stderr',
    'job_stdout',
    'job_stderr',
    'traceback',
]
FLATTEN_ROWS_ON = [
    # All these fields must be the same for a row to be considered a duplicate
    'create_date',  # must be created from create_time field
    'session_id',
    'state',
]
DROP_JOB_STATES = [
    'deleting',
    'waiting',
    'running',
    'new',
]

REQUIRED_ENV_VARS = [
    'GALAXY_PG_JOB_TABLE',
    'GALAXY_PG_PASSWORD',
    'GALAXY_PG_HOST',
]

ENV_VARS_ERROR_MSG = (
    f"The following env vars are required: {', '.join(REQUIRED_ENV_VARS)}.\n"
    "These variables will be read from a .env file in the working directory."
)


def main():
    """Do the thing."""
    args = parse_args()
    with GalaxyDB() as db:
        if args.tool_id:
            df = db.fetch_rows_for_tool(args.tool_id)
            fname = args.out or f"{args.tool_id}.csv"
            print(f"Writing job rows to {fname}...")
            df.to_csv(fname, index=False)
        else:
            db.fetch_all_tools(limit=args.limit, outfile=args.out)


def parse_args():
    """Parse CLI arguments."""
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        '--tool_id',
        required=False,
        help=(
            'Tool ID to filter on e.g. "antismash".'
            ' Will match against partial IDs'
        ),
    )
    parser.add_argument(
        '-o',
        '--out',
        required=False,
        default=DEFAULT_OUTFILE,
        help=(
            'Output CSV file name. Defaults to <tool_id>.csv'
        ),
    )
    parser.add_argument(
        '--limit',
        required=False,
        help=(
            'Limit number of tool IDs to fetch. Useful for testing.'
        ),
    )
    args = parser.parse_args()
    return args


class GalaxyDB:
    """Interact with the postgres database of a remote Galaxy instance."""

    def __init__(self):
        self.conn = self.get_connection()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, exc_traceback):
        self.conn.close()
        if self.server:
            self.server.stop()

    def get_connection(self):
        """Return a connection to the remote postgres database.

        Can use an SSH tunnel but defaults to remote psql connection.
        """
        for var in REQUIRED_ENV_VARS:
            assert os.environ.get(var), ENV_VARS_ERROR_MSG

        params = {
            'database': DATABASE['database'],
            'user': DATABASE['user'],
            'password': DATABASE['password'],
            'host': DATABASE['host'],
            'port': DATABASE['port'],
        }

        if DATABASE['ssh_key'] and DATABASE['ssh_username']:
            self.server = SSHTunnelForwarder(
                (DATABASE['host'], 22),
                ssh_username=DATABASE['ssh_username'],
                ssh_pkey=DATABASE['ssh_key'],
                remote_bind_address=('localhost', DATABASE['port']),
            )
            self.server.start()
            params['host'] = 'localhost'
            params['port'] = self.server.local_bind_port
        else:
            self.server = None

        conn = psycopg2.connect(**params)
        conn.set_session(readonly=True)
        return conn

    def fetch_all_tools(self, limit: int = None, outfile: str = None):
        """Fetch job rows for all tools and extract status counts.

        Flatten rows by FLATTEN_ROWS_ON fields before enumerating, such that
        a user running multiple jobs in one day is counted only once. This
        eliminates inflated counts due to submission of collections.

        Write output to CSV file with fields<tool_id, ok, paused, deleted,
        error, error_ratio> where the last field is the ratio of errored jobs.
        """
        tool_status = {}
        tool_ids = self.fetch_tool_ids(strip=True, limit=limit)
        print(f"Fetched {len(tool_ids)} tool IDs to query")

        for tool_id in tool_ids:
            print(f"\nFetching jobs for tool '{tool_id}'...")
            df = self.fetch_rows_for_tool(tool_id)
            dff = flatten_rows(df)
            tool_state_counts = (
                dff.groupby('tool_id')
                .agg({'state': 'value_counts'})
            )
            for multi_ix in tool_state_counts.index:
                tool_id = multi_ix[0]
                state = multi_ix[1]
                if state in DROP_JOB_STATES:
                    continue
                count = tool_state_counts.loc[multi_ix, 'state']
                if tool_id not in tool_status:
                    tool_status[tool_id] = {
                        'ok': 0,
                        'error': 0,
                        'total': len(df),
                        'total_users': count_unique_users(df),
                        'error_users': count_unique_users(df, state='error'),
                    }
                tool_status[tool_id][state] = count.astype(int)

        df_out = pd.DataFrame.from_dict(tool_status, orient='index')
        df_out['error_ratio'] = (
            df_out['error']
            / df_out['ok'].apply(lambda x: x or 0.1)  # Avoid zero-division
        ).round(2)
        df_out['total'] = (
            df_out['ok']
            + df_out['paused']
            + df_out['deleted']
            + df_out['error']
        ).astype(int)

        fname = outfile or DEFAULT_OUTFILE
        df_out.to_csv(fname, index=True)
        print(f"\nTool status dataframe written to {fname}")

    def fetch_tool_ids(
        self,
        strip: bool = False,
        limit: int = None
    ) -> list[str]:
        """Return a list of unique tool_ids from the database.

        Tool versions are stripped from the end of the ID.
        """
        def strip_id(i):
            """Strip version from tool ID."""
            if '/' in i:
                return '/'.join(i.split('/')[:-1])
            return i

        query = f"SELECT DISTINCT tool_id FROM {DATABASE['table']}"
        if limit:
            query += f" LIMIT {limit}"
        query += ';'
        df = pd.read_sql_query(query, self.conn)
        ids = df['tool_id'].tolist()
        if strip:
            ids = [strip_id(i) for i in ids]
        unique_ids = []
        for i in ids:
            if i not in unique_ids:
                unique_ids.append(i)
        return unique_ids

    def fetch_rows_for_tool(
        self,
        tool_id: str,
        error: bool = None,
        limit: int = None,
        exact: bool = True,
        since: datetime = None,
    ) -> pd.DataFrame:
        """Fetch job rows from database for given tool_id."""
        query = f"SELECT {','.join(COLUMNS)} FROM {DATABASE['table']}"
        if exact:
            query += (
                f" WHERE (tool_id = '{tool_id}'"
                f" OR tool_id LIKE '{tool_id}/%')"  # for version stripped ID
            )
        else:
            query += f" WHERE tool_id LIKE '%{tool_id}%'"
        if error is True:
            query += " AND state = 'error'"
        if error is False:
            query += " AND state = 'ok'"
        if since:
            since_str = since.strftime('%Y-%m-%d %H:%M:%S')
            query += f" AND create_time > '{since_str}'"
        if limit:
            query += f" LIMIT {limit}"
        query += ';'
        df = pd.read_sql_query(query, self.conn)
        print(f"Fetched {len(df)} rows for tool ID {tool_id}")
        return df


def count_unique_users(df: pd.DataFrame, state: str = None) -> int:
    """Return number of unique users for errored jobs."""
    if state:
        df = df.loc[df['state'] == state]
    return df['user_id'].nunique()


def flatten_rows(df: pd.DataFrame) -> pd.DataFrame:
    """Flatten dataframe to specified distinct fields."""
    df['create_date'] = df['create_time'].apply(lambda x: x.date())
    df = df.drop_duplicates(subset=FLATTEN_ROWS_ON, keep="first")
    return df


if __name__ == '__main__':
    main()
