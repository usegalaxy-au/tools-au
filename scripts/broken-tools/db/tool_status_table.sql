-- Create a table to store tool error cluster data
-- DB galaxy-tools
-- USER tooldev

BEGIN TRANSACTION;

CREATE TABLE job_states (
    id                     SERIAL PRIMARY KEY,
    tool_id                VARCHAR (200),
    ok                     INT,
    error                  INT,
    total                  INT,
    error_ratio            NUMERIC (8, 2)
);

-- Bulk import tool status data from CSV

COPY job_states (
    tool_id,
    ok,
    error,
    total,
    error_ratio
)
FROM '/home/ubuntu/tool_status_flat.csv'
DELIMITER ','
CSV HEADER;

COMMIT;
