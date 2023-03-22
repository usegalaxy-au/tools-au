"""Cluster stderr to enumerate errors per tool."""

# cosine similarity

import os
import Levenshtein
from fetch_jobs import fetch_rows_for_tool, fetch_tool_ids

CLUSTER_OUT_DIR = 'clusters'
TOOLS_LIMIT = 100
STDERR_MAX_LINES = 15
LEVENSHTEIN_CUTOFF = 0.8
OUTFILE = f'tool_stderr_clustered_LEV{LEVENSHTEIN_CUTOFF}.csv'
HEADER = ('tool_id', 'cluster', 'stderr', 'count')


def truncate(string: str, lines: int = None) -> str:
    """Truncate a string to a specified number of lines."""
    if string.count('\n') < lines:
        return string
    return '\n'.join(string.splitlines()[-lines:])


def write_err_cluster(tool_id: str, index: int, err: str):
    """Write clustered error to file."""
    os.makedirs(CLUSTER_OUT_DIR, exist_ok=True)
    path = f"{CLUSTER_OUT_DIR}/{tool_id}__{index}.txt"
    with open(path, 'a+') as f:
        f.write(f'\n\n{err}\n\n')
        f.write('-' * 80 + '\n')


with open(OUTFILE, 'a+') as f:
    f.write(','.join(HEADER) + '\n')

rows = []
tool_ids = fetch_tool_ids(strip=True, limit=TOOLS_LIMIT)

for tool_id in tool_ids:
    print(f"Fetching job rows for tool '{tool_id}'...")
    clustered_stderr = []
    df = fetch_rows_for_tool(tool_id, error=True)
    for ix, row in df.iterrows():
        err = row['tool_stderr'] or row['tool_stdout']
        if not err:
            continue
        err = truncate(err, lines=STDERR_MAX_LINES)
        matched = False
        for ix, item in enumerate(clustered_stderr):
            if Levenshtein.ratio(err, item['err']) > LEVENSHTEIN_CUTOFF:
                item['count'] += 1
                matched = True
                write_err_cluster(tool_id, ix, err)
                break
        if not matched:
            clustered_stderr.append({
                'count': 1,
                'err': err,
            })
            write_err_cluster(tool_id, ix, err)

    for i, item in enumerate(clustered_stderr):
        formatted_err = '"' + item['err'].replace('"', "'") + '"'
        row = (tool_id, str(i), formatted_err, str(item['count']))
        with open(OUTFILE, 'a+') as f:
            f.write(','.join(row) + '\n')


print('Done')
