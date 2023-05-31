Fgenesh is a licensed genome annotation tool.


Requirements to run fgenesh on Galaxy.
1) setup the authentication docker file under .docker/config.json
2) setup the Non redundant NCBI DB , gene matrix and Fgenesh parameters on Galaxy manually. Folder /mnt/galaxy/local_tools/db
3) move all the loc files to the tool-data folder under the Galaxy root directory.
4) update the db path in all loc files
5) add the wrapper to local_tool_conf.xml (dev) or tool_conf.xml (production)
6) create a customize tool_data_table_conf.xml in /mnt/galaxy/local_tools/db folder
7) append the tool_data_table_conf.xml to tool_data_table_config_path in galaxy.xml
