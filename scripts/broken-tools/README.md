# Collect tool error stats from your Galaxy server


> [!WARNING]
> Before running this tool, think about the load that will be put on the Galaxy DB by this query.
> If you fetch all jobs for all tools from the last 5 years, that's a lot of big requests for the DB to handle.
> Make sure this is not going to impact a production service! If unsure, use a copy of the database.
> A database with a `job` table is all that's required.

## What does it do?

The [cluster_errors.py](https://github.com/usegalaxy-au/tools-au/blob/master/scripts/broken-tools/cluster_errors.py)
script connects to a remote PostgreSQL server (i.e. your Galaxy DB), fetches jobs since date X and performs
clustering on error messages for each tool. 

The main output is a CSV file which enumerates job states against tool IDs,
where an error ratio of 1.0 indicates a job that fails 50% of the time:

`./data/tool_status_flat.csv`
|tool_id       |ok |error|total|error_ratio|
|--------------|---|-----|-----|-----------|
|addValue      |26 |0    |31   |0.0        |
|iuc/addValue  |60 |0    |70   |0.0        |
|alphafold     |0  |1    |1    |10.0       |
|alphafold_test|7  |11   |20   |1.57       |

Another useful output comes from clustering tool IDs by their error message using DBSCAN method from Scikit-Learn.
The clustering allows some variability in error messages within a cluster e.g. different path names, timestamps. 
This produces a CSV file where each row is a "tool error" with an error message and count estimate for that particular error:

`./data/dbscan/tool_err_summary.csv`
|tool_id       |latest_version|cluster_id|count|last_seen|representative_error                                                                        |
|--------------|--------------|----------|-----|---------|--------------------------------------------------------------------------------------------|
|alphafold_test|2.1.2+galaxy2 |0         |8    |2022-09-15 03:41:53.145222|Failed to communicate with remote job server.                              |
|alphafold_test|2.3.1+galaxy0 |2         |5    |2023-02-09 20:26:02.702952|FileNotFoundError: No such file or directory: 'missing-output-file.pkl'    |
|iuc/seqtk_seq |2.1.5         |0         |3    |2023-02-15 08:39:33.831779|ValueError: Shape tuple is incompatible with data                          |

## How does this affect the Galaxy DB?

The script with run a series of these queries, for each `tool_id` it finds in the jobs table:

```sql
SELECT * FROM job WHERE tool_id LIKE %tool_id% AND create_time < MY_CUTOFF_DATE;
```

## Running the script

Create a `.env` file by copying `.env.sample` and modifying to match your Galaxy server:

https://github.com/usegalaxy-au/tools-au/blob/8c6af15431496891e780fd845cace1bf725f4986/scripts/broken-tools/.env.sample#L1-L10

Some params that you might like to tweak before running 
[cluster_errors.py](https://github.com/usegalaxy-au/tools-au/blob/master/scripts/broken-tools/cluster_errors.py):

https://github.com/usegalaxy-au/tools-au/blob/8c6af15431496891e780fd845cace1bf725f4986/scripts/broken-tools/cluster_errors.py#L12-L29

- Take special care that the `FETCH_JOBS_SINCE` date is not too far in the past. 1-6 months provides sufficient data for most cases.
- If doing a test run, take advantage of the `LIMIT` param to limit the number of jobs fetched to something easy like 200.

### Install dependencies

```sh
# Unix
python3.10 -m venv venv
source venv
pip install -r requirements.txt
```

### Run the script

```sh
python cluster_errors.py
```

It can take many hours, depending on date limit so better to run on a server like:

```sh
nohup python cluster_errors.py > cluster-errors.out &
```
