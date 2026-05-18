planemo test \
    --docker \
    --docker_run_extra_arguments \
    "-v /data/phastest:/data/phastest:ro -e PHASTEST_DB_PATH=/data/phastest"

    # To test with DB dir mounted directly:
    # "-v /data/phastest:/home/phastest/phastest-app/DB:ro"
