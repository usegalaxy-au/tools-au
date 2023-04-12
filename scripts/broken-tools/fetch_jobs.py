#!/usr/bin/env python3

"""Read in broken tools data from remote PG database and filter data."""

import os
import argparse
import psycopg2
import pandas as pd
from dotenv import load_dotenv

load_dotenv()

DEFAULT_OUTFILE = 'tool_status_flat.csv'
DATABASE = {
    'database': os.environ.get('GXTOOLS_PG_DATABASE'),
    'user': os.environ.get('GXTOOLS_PG_USER'),
    'password': os.environ.get('GXTOOLS_PG_PASSWORD'),
    'host': os.environ.get('GXTOOLS_PG_HOST'),
    'port': os.environ.get('GXTOOLS_PG_PORT'),
}
TABLE_NAME = 'jobs'
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

ENV_VARS_ERROR_MSG = (
    "Env vars GXTOOLS_PG_PASSWORD and GXTOOLS_PG_HOST must be set.\n"
    "These variables will be read from a .env file in the working directory."
)


def main():
    """Do the thing."""
    args = parse_args()
    if args.tool_id:
        df = fetch_rows_for_tool(args.tool_id)
        fname = args.out or f"{args.tool_id}.csv"
        print(f"Writing job rows to {fname}...")
        df.to_csv(fname, index=False)
    else:
        fetch_all_tools(limit=args.limit, outfile=args.out)


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


def fetch_all_tools(limit: int = None, outfile: str = None):
    """Fetch job rows for all tools and extract status counts.

    Flatten rows by FLATTEN_ROWS_ON fields before enumerating, such that
    a user running multiple jobs in one day is counted only once. This
    eliminates inflated counts due to submission of collections.

    Write output to CSV file with fields <tool_id, ok, paused, deleted, error,
    error:ok> where the last field is the ratio of errored jobs.
    """
    tool_status = {}
    tool_ids = fetch_tool_ids(strip=True, limit=limit)
    print(f"Fetched {len(tool_ids)} tool IDs to query.")

    for tool_id in tool_ids:
        print(f"\nFetching jobs for tool '{tool_id}'...")
        df = fetch_rows_for_tool(tool_id)
        dff = flatten_rows(df)
        tool_state_counts = (
            dff.groupby('tool_id')
            .agg({'state': 'value_counts'})
        )
        for multi_ix in tool_state_counts.index:
            tool_id = multi_ix[0]
            state = multi_ix[1]
            count = tool_state_counts.loc[multi_ix, 'state']
            if tool_id not in tool_status:
                tool_status[tool_id] = {
                    'ok': 0,
                    'paused': 0,
                    'deleted': 0,
                    'error': 0,
                    'total_users': count_unique_users(df),
                    'error_users': count_unique_users(df, state='error'),
                }
            tool_status[tool_id][state] = count

    df_out = pd.DataFrame.from_dict(tool_status, orient='index')
    df_out['error:ok'] = (
        df_out['error']
        / df_out['ok'].apply(lambda x: x or 0.1)
    )
    fname = outfile or DEFAULT_OUTFILE
    df_out.to_csv(fname, index=True)
    print(f"\nTool status dataframe written to {fname}")


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


def fetch_tool_ids(strip: bool = False, limit: int = None) -> list[str]:
    """Return a list of unique tool_ids from the database.

    Tool versions are stripped from the end of the ID.
    """
    def strip_id(i):
        """Strip version from tool ID."""
        if '/' in i:
            return '/'.join(i.split('/')[:-1])
        return i

    query = f"SELECT DISTINCT tool_id FROM {TABLE_NAME}"
    if limit:
        query += f" LIMIT {limit}"
    query += ';'
    df = pd.read_sql_query(
        query,
        get_connection(),
    )
    ids = df['tool_id'].tolist()
    if strip:
        ids = [strip_id(i) for i in ids]
    unique_ids = []
    for i in ids:
        if i not in unique_ids:
            unique_ids.append(i)
    return unique_ids


def fetch_rows_for_tool(
        tool_id: str,
        error: bool = None,
        limit: int = None,
        exact: bool = True) -> pd.DataFrame:
    """Fetch job rows from database for given tool_id (fuzzy)."""
    query = f"SELECT {','.join(COLUMNS)} FROM {TABLE_NAME}"
    if exact:
        query += f" WHERE tool_id = '{tool_id}' AND"
    else:
        query += f" WHERE tool_id LIKE '%{tool_id}%' AND"
    if error is True:
        query += " state = 'error'"
    if error is False:
        query += " state = 'ok'"
    query = query.strip(' AND')
    if limit:
        query += f" LIMIT {limit}"
    query += ';'
    df = pd.read_sql_query(
        query,
        get_connection(),
    )
    print(f"Fetched {len(df)} rows for tool ID {tool_id}.")
    return df


def get_connection():
    """Return a connection to the remote PG database."""
    assert (
        DATABASE['password'] and DATABASE['host']
    ), ENV_VARS_ERROR_MSG
    conn = psycopg2.connect(**DATABASE)
    conn.set_session(readonly=True)
    return conn


if __name__ == '__main__':
    main()
