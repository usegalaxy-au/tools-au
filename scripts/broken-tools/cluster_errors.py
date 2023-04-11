"""Test clustering."""

import os
import pandas as pd

from fetch_jobs import fetch_rows_for_tool, fetch_tool_ids
from clustered_dataframe import ClusteredDataFrame

EPSILON = 0.2
CLUSTER_MIN_SAMPLES = 3
TOOL_ID_LIMIT = 100
OUT_DIR = 'data/dbscan'
OUT_DIR_CLUSTERS = os.path.join(OUT_DIR, 'clusters')
SUMMARY_OUTFILE = os.path.join(OUT_DIR, 'tool_err_summary.csv')
OUTPUT_COLS = [
    'tool_id',
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
    tool_data_path = os.path.join(OUT_DIR, f'{tool_id_safe}.rows.csv')
    if os.path.exists(tool_data_path):
        df = pd.read_csv(tool_data_path)
    else:
        df = fetch_rows_for_tool(tool_id, error=True)
        df.to_csv(tool_data_path, index=False)
    return df


def sortable_version(x):
    """Represent a galaxy tool version as a tuple that can be compared.

    e.g. 2.1.3+galaxy1.
    """
    if '+' in x:
        v_num, suffix = x.split('+')
    else:
        v_num = x
        suffix = None
    version = [
        int(v)
        for v in v_num.split('.')
    ] + [suffix]
    return tuple(version)


def main():
    """Do the thing."""

    if os.path.exists(SUMMARY_OUTFILE):
        os.remove(SUMMARY_OUTFILE)

    for d in [OUT_DIR, OUT_DIR_CLUSTERS]:
        os.makedirs(d, exist_ok=True)

    tool_id_list = fetch_tool_ids(strip=True, limit=TOOL_ID_LIMIT)

    for tool_id in tool_id_list:
        tool_id_safe = tool_id.replace('/', '')
        df = get_data_for_id(tool_id, tool_id_safe)
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
            index=False)
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
        summary['latest_version'] = (
            summary['cluster_id']
            .apply(
                lambda x:
                    cl.loc[cl['cluster_id'] == x]
                    .reindex(index=sorted(
                        df['tool_version'],
                        key=sortable_version,
                        reverse=True,
                    ).index)
                    .iloc[0]
            )
        )
        summary.sort_values('count', ascending=False, inplace=True)
        summary[OUTPUT_COLS].to_csv(
            SUMMARY_OUTFILE,
            mode='a',
            header=tool_id == tool_id_list[0],
            index=False,
        )

    print("\nDone\n")


if __name__ == '__main__':
    main()
