-- Set up a postgres database for errored jobs
-- DB galaxy-tools
-- USER tooldev

BEGIN TRANSACTION;

CREATE TABLE jobs (
    id                     SERIAL PRIMARY KEY,
    create_time            TIMESTAMP,
    update_time            TIMESTAMP,
    history_id             INT,
    tool_id                VARCHAR (200),
    tool_version           VARCHAR (100),
    state                  VARCHAR (200),
    info                   VARCHAR (5000),
    command_line           VARCHAR,
    param_filename         VARCHAR (1000),
    runner_name            VARCHAR (1000),
    tool_stdout            VARCHAR,
    tool_stderr            VARCHAR,
    traceback              VARCHAR,
    session_id             INT,
    job_runner_name        VARCHAR (200),
    job_runner_external_id INT,
    library_folder_id      VARCHAR (200),
    user_id                INT,
    imported               VARCHAR (200),
    object_store_id        VARCHAR (200),
    params                 VARCHAR (100000),
    handler                VARCHAR (200),
    exit_code              INT,
    destination_id         VARCHAR (100),
    destination_params     VARCHAR (10000),
    dependencies           VARCHAR,
    copied_from_job_id     VARCHAR (200),
    job_messages           VARCHAR,
    job_stdout             VARCHAR,
    job_stderr             VARCHAR,
    dynamic_tool_id        VARCHAR (200),
    galaxy_version         VARCHAR (20)
);

-- Bulk import jobs table from CSV

COPY jobs
FROM '/mnt/vdb/scratch/jobs-dump.csv'
DELIMITER ','
CSV HEADER;

COMMIT;
