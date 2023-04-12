"""Test clustering."""

import os
import shutil
import pandas as pd
from pathlib import Path
from datetime import datetime

from fetch_jobs import GalaxyDB
from clustered_dataframe import ClusteredDataFrame

# Params
EPSILON = 0.2
CLUSTER_MIN_SAMPLES = 3
TOOL_ID_LIMIT = 10
FETCH_JOBS_SINCE = datetime.fromisoformat('2023-01-01')
APPEND = False  # Append to summary file, if exists, otherwise overwrite

OUT_DIR = Path('data/dbscan')
OUT_DIR_CLUSTERS = OUT_DIR / 'clusters'
OUT_CACHE_DIR = OUT_DIR / 'cache'
SUMMARY_OUTFILE = OUT_DIR / 'tool_err_summary.csv'
OUTPUT_COLUMNS = [
    'tool_id',
    'latest_version',
    'cluster_id',
    'count',
    'last_seen',
    'representative_error',
]

CLUSTER_OUTPUT_COLUMNS = [
    "create_time",
    "tool_id",
    "tool_version",
    "user_id",
    "session_id",
    "cluster_id",
    "command_line",
    "params",
    "info",
    "state",
    "tool_stdout",
    "tool_stderr",
    "tokenized_err",
    "job_stdout",
    "job_stderr",
    "traceback",
]


def get_data_for_id(db, tool_id, tool_id_safe):
    """Fetch tool error data."""
    tool_data_path = OUT_CACHE_DIR / f'{tool_id_safe}.rows.csv'
    if tool_data_path.exists():
        df = pd.read_csv(tool_data_path)
    else:
        df = db.fetch_rows_for_tool(
            tool_id,
            error=True,
            since=FETCH_JOBS_SINCE,
        )
        df.to_csv(tool_data_path, index=False)
    return df


def data_exists_for_tool(tool_id):
    """Return True if data already exists in the summary CSV."""
    if not (APPEND or SUMMARY_OUTFILE.exists()):
        return False
    df = pd.read_csv(SUMMARY_OUTFILE)
    return tool_id in df.tool_id.values


def main():
    """Do the thing."""
    if not APPEND and SUMMARY_OUTFILE.exists():
        os.remove(SUMMARY_OUTFILE)

    for d in [OUT_DIR_CLUSTERS]:
        if not APPEND and d.exists():
            shutil.rmtree(d)
        os.makedirs(d, exist_ok=True)

    for d in [OUT_DIR, OUT_CACHE_DIR]:
        os.makedirs(d, exist_ok=True)

    with GalaxyDB() as db:
        tool_id_list = db.fetch_tool_ids(strip=True, limit=TOOL_ID_LIMIT)

        print(f"\nCollected {len(tool_id_list)} tool IDs to cluster.\n")

        for tool_id in tool_id_list:
            tool_id_safe = tool_id.replace('/', '_')
            if data_exists_for_tool(tool_id):
                continue
            df = get_data_for_id(db, tool_id, tool_id_safe)
            if df.empty:
                continue

            print(f"Clustering errors for tool: {tool_id}")

            # TODO: manually set "out of mem" and "core dumped" clusters?

            cl = ClusteredDataFrame(
                df,
                cluster_min_samples=CLUSTER_MIN_SAMPLES,
                eps=EPSILON,
            )
            # Output cluster data for debugging
            cl[CLUSTER_OUTPUT_COLUMNS].to_csv(
                OUT_DIR_CLUSTERS / f'{tool_id_safe}.clusters.csv',
                index=False,
                header=True,
            )
            summary = cl.get_cluster_summary()
            summary[OUTPUT_COLUMNS].to_csv(
                SUMMARY_OUTFILE,
                mode='a',
                header=not SUMMARY_OUTFILE.exists(),
                index=False,
            )

    print("\nDone\n")


if __name__ == '__main__':
    main()
