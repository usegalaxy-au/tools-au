PHASTEST Installation Guide
============================

This document describes how to install and configure PHASTEST for use in Galaxy.

Overview
--------

PHASTEST (PHAge Search Tool with Enhanced Sequence Translation) provides rapid identification and annotation of prophage sequences within bacterial genomes and plasmids. This Galaxy wrapper uses a Docker container to run PHASTEST analyses.

Requirements
------------

Reference Databases
~~~~~~~~~~~~~~~~~~~

PHASTEST requires reference database files to perform prophage identification and annotation. These databases are used for:

- **Prophage Database**: Core database for identifying prophage sequences
- **Swissprot**: Used in "lite" annotation mode for faster protein annotation
- **PHAST-BSD Bacterial Database**: Used in "deep" annotation mode for comprehensive bacterial protein annotation

Database setup
~~~~~~~~~~~~~~

The PHASTEST database files can be downloaded from the official PHASTEST website with:

    wget https://phastest.ca/download_file/docker-database -O phastest_dbs.tar.gz

PHASTEST requires the ``PHASTEST_DB_PATH`` environment variable to be set to the location of the downloaded database files.

**Setting the environment variable:**

Add the following to your Galaxy TPV config:

.. code-block:: yaml

      toolshed.g2.bx.psu.edu/repos/proteaglycosciences/glycombo/glycombo/.*:
        params:
          docker_enabled: true
          singularity_enabled: false
        env:
          PHASTEST_DB_PATH: /path/to/phastest_dbs

Additional Resources
--------------------

- Official PHASTEST website: https://phastest.ca/
- Database downloads: https://phastest.ca/databases
- PHASTEST documentation: https://phastest.ca/ (web service documentation)

Support
-------

For issues related to:

- PHASTEST itself: Visit https://phastest.ca/
- This Galaxy wrapper: Contact your Galaxy administrator or submit an issue to the tool repository
