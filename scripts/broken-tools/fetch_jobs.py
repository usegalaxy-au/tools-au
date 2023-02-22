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
    'database': 'galaxy-tools',
    'user': 'ubuntu',
    'password': os.environ.get('GXTOOLS_PG_PASSWORD'),
    'host': os.environ.get('GXTOOLS_PG_HOST'),
    'port': '5432',
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
    'create_date',
    'session_id',
    'state',
]

ENV_VARS_ERROR_MSG = (
    "Env vars GXTOOLS_PG_PASSWORD and GXTOOLS_PG_HOST must be set.\n"
    "These variables will be read from a .env file in the working directory."
)


def parse_args():
    """Parse CLI arguments."""
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        'tool_id',
        required=False,
        help=(
            'Tool ID to filter on e.g. "antismash".'
            ' Will match against partial IDs',
        ),
    )
    parser.add_argument(
        '-o',
        '--out',
        required=False,
        default=DEFAULT_OUTFILE,
        help=(
            'Output CSV file name. Defaults to <tool_id>.csv',
        ),
    )
    parser.add_argument(
        '--limit',
        required=False,
        help=(
            'Limit number of tool IDs to fetch. Useful for testing.',
        ),
    )
    args = parser.parse_args()
    return args


def fetch_all_tools(limit=None, outfile=None):
    """Fetch all tools and save flattened rows to CSV."""
    tool_status = {}
    tool_ids = fetch_tool_ids(strip=True, limit=limit)

    for tool_id in tool_ids:
        print(f"\nFetching jobs for tool '{tool_id}'...")
        df = fetch_rows_for_tool(tool_id)
        # df.to_csv(f"{tool_id}_job_rows.csv")
        df = flatten_rows(df)
        # df.to_csv(f"{tool_id}_job_rows_flat.csv")
        tool_state_counts = (
            df.groupby('tool_id')
            .agg({'state': 'value_counts'})
        )
        # tool_state_counts.to_csv(f"{tool_id}_status_count.csv")
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


def flatten_rows(df):
    """Flatten dataframe to one row per session/day."""
    # Create a date column
    df['create_date'] = df['create_time'].apply(lambda x: x.date())
    # Keep only the first row for each session/date. This way we eliminate
    # multiple jobs from one user on a single day.
    df = df.drop_duplicates(subset=FLATTEN_ROWS_ON, keep="first")
    return df


def fetch_tool_ids(strip=False, limit=None):
    """Return a list of unique tool_ids from the database."""
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
    return ids


def fetch_rows_for_tool(tool_id, error=None, limit=None):
    """Fetch job rows from database and return as dataframe."""
    query = f"SELECT {','.join(COLUMNS)} FROM {TABLE_NAME}"
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
    args = parse_args()
    if args.tool_id:
        df = fetch_rows_for_tool(args.tool_id)
        fname = args.out or f"{args.tool_id}.csv"
        print(f"Writing job rows to {fname}...")
        df.to_csv(fname, index=False)
    else:
        fetch_all_tools(limit=args.limit, outfile=args.out)
