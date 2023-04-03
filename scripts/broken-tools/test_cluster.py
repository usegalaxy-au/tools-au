"""Test clustering.

TODO:

"""

from fetch_jobs import fetch_rows_for_tool
from clustered_dataframe import ClusteredDataFrame

TOOL_ID = 'alphafold'
EPSILON = 0.5
CLUSTER_MIN_SAMPLES = 3

tool_id_safe = TOOL_ID.replace('/', '')

for EPSILON in (0.5, 0.45, 0.3, 0.35):
    df = fetch_rows_for_tool(TOOL_ID, error=True)
    df.to_csv(f'{tool_id_safe}.rows.csv', index=False)
    cl = ClusteredDataFrame(
        df,
        cluster_min_samples=CLUSTER_MIN_SAMPLES,
        eps=EPSILON,
    )
    summary = cl.get_cluster_summary()
    summary.to_csv(
        f'{tool_id_safe}.E{EPSILON}.summary.csv',
        index=False,
    )
    print(summary)
