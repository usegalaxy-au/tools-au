-- Create a table to store tool error cluster data
-- DB galaxy-tools
-- USER tooldev

BEGIN TRANSACTION;

CREATE TABLE clusters (
    id                     SERIAL PRIMARY KEY,
    tool_id                VARCHAR (200),
    latest_version         VARCHAR (100),
    cluster_id             INT,
    count                  INT,
    last_seen              TIMESTAMP,
    representative_error   VARCHAR
);

-- Bulk import cluster data from CSV

COPY clusters(
    tool_id,
    latest_version,
    cluster_id,
    count,
    last_seen,
    representative_error
)
FROM '/mnt/vdb/scratch/clusters.csv'
DELIMITER ','
CSV HEADER;

COMMIT;
