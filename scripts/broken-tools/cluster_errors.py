"""Test clustering."""

import os
import re
import shutil
import pandas as pd

from fetch_jobs import fetch_rows_for_tool, fetch_tool_ids
from clustered_dataframe import ClusteredDataFrame

# Params
EPSILON = 0.2
CLUSTER_MIN_SAMPLES = 3
TOOL_ID_LIMIT = None
APPEND = True  # Append to summary file, if exists

OUT_DIR = 'data/dbscan'
OUT_DIR_CLUSTERS = os.path.join(OUT_DIR, 'clusters')
OUT_CACHE_DIR = os.path.join(OUT_DIR, 'rows')
SUMMARY_OUTFILE = os.path.join(OUT_DIR, 'tool_err_summary.csv')
OUTPUT_COLS = [
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


def get_data_for_id(tool_id, tool_id_safe):
    """Fetch tool error data."""
    tool_data_path = os.path.join(OUT_CACHE_DIR, f'{tool_id_safe}.rows.csv')
    if os.path.exists(tool_data_path):
        df = pd.read_csv(tool_data_path)
    else:
        df = fetch_rows_for_tool(tool_id, error=True)
        df.to_csv(tool_data_path, index=False)
    return df


def sortable_version(x):
    """Represent a galaxy tool version as a sortable tuple.

    e.g. 2.1.3+galaxy1.
    """
    def pad_v(v):
        """Pad a version number with zeros."""
        try:
            padded = f'{int(v):03}'
        except ValueError:
            padded = str(v)
        return padded

    if type(x) == float:
        return tuple(str(x))
    if '+' in x:
        v_num, suffix = x.split('+', 1)
    else:
        v_num = x
        suffix = None
    v_num = re.sub(r'[^\w\d\.]|\_', '.', v_num)  # Replace non-numeric with '.'
    version = [
        pad_v(v)
        for v in v_num.split('.')
    ]
    if suffix:
        version += [suffix]
    return tuple(version)


def data_exists_for_tool(tool_id):
    """Return True if data already exists in the summary CSV."""
    if not (APPEND or os.path.exists(SUMMARY_OUTFILE)):
        return False
    df = pd.read_csv(SUMMARY_OUTFILE)
    return tool_id in df.tool_id.values


def main():
    """Do the thing."""
    if not APPEND and os.path.exists(SUMMARY_OUTFILE):
        os.remove(SUMMARY_OUTFILE)

    for d in [OUT_DIR_CLUSTERS]:
        if not APPEND and os.path.exists(d):
            shutil.rmtree(d)
        os.makedirs(d)

    for d in [OUT_DIR, OUT_CACHE_DIR]:
        os.makedirs(d, exist_ok=True)

    # tool_id_list = ['scanpy_filter_cells']  # hard-code tool ID for debugging
    tool_id_list = fetch_tool_ids(strip=True, limit=TOOL_ID_LIMIT)

    for tool_id in tool_id_list:
        tool_id_safe = tool_id.replace('/', '')
        if data_exists_for_tool(tool_id):
            continue
        df = get_data_for_id(tool_id, tool_id_safe)
        if df.empty:
            continue
        print(f"\nClustering errors for tool: {tool_id}\n")
        # TODO: manually assign clusters for "out of mem" and "core dumped"?
        cl = ClusteredDataFrame(
            df,
            cluster_min_samples=CLUSTER_MIN_SAMPLES,
            eps=EPSILON,
        )
        # Output cluster data for debugging
        cl.sort_values('cluster_id', inplace=True)
        cl[CLUSTER_OUTPUT_COLUMNS].to_csv(
            os.path.join(OUT_DIR_CLUSTERS, f'{tool_id_safe}.clusters.csv'),
            index=False,
            header=True,
        )
        summary = cl.get_cluster_summary()
        summary['tool_id'] = [tool_id for i in range(len(summary))]
        summary['last_seen'] = (
            summary['cluster_id']
            .apply(
                lambda x:
                    cl.loc[cl['cluster_id'] == x]
                    .sort_values('create_time', ascending=False)['create_time']
                    .iloc[0]
            )
        )
        cl['sortable_version'] = cl['tool_version'].apply(sortable_version)
        cl.sort_values('sortable_version', inplace=True, ascending=False)
        summary['latest_version'] = (
            summary['cluster_id']
            .apply(
                lambda x: cl.loc[cl['cluster_id'] == x, 'tool_version'].iloc[0]
            )
        )
        summary.sort_values('count', ascending=False, inplace=True)
        summary[OUTPUT_COLS].to_csv(
            SUMMARY_OUTFILE,
            mode='a',
            header=not os.path.exists(SUMMARY_OUTFILE),
            index=False,
        )

    print("\nDone\n")


if __name__ == '__main__':
    main()
