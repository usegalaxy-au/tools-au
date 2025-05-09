Fgenesh is a licensed genome annotation tool.


Requirements to run fgenesh on Galaxy.
1) setup the authentication docker file under .docker/config.json
2) setup the Non redundant NCBI DB , gene matrix and Fgenesh parameters on Galaxy manually. Folder /mnt/galaxy/local_tools/db
3) move all the loc files to the tool-data folder under the Galaxy root directory.
4) update the db path in all loc files
5) add the wrapper to local_tool_conf.xml (dev) or tool_conf.xml (production)
6) create a customize tool_data_table_conf.xml in /mnt/galaxy/local_tools/db folder
7) append the tool_data_table_conf.xml to tool_data_table_config_path in galaxy.xml

Supported Species is based on the species offered in the gene matrix by Softberry

## Tool versions
Fgenesh tools wrapped for Galaxy is using Fgenesh v2024.2.

## Update 9/5/2025
- updated Fgenesh from version 7.2.2 to version 2024.2
- added three new wrappers fgenesh_annotate_mrnas.xml, fgenesh_check_mrna.xml and fgenesh_renumber.xml to Fgenesh v2024.2
- fgenesh_get_mrnas_gc.xml is available in v7.2.2 and replaced with fgenesh_get_mrnas.xml in v2024.2
- create two separate folders 1) 7.2.2 and 2) 2024.2 for version control
- update the `local_tool_conf.xml <https://github.com/mthang/infrastructure/blob/master/files/galaxy/config/local_tool_conf_dev.xml>`_ entry to manage different version of Fgenesh on dev and same as production.

## Fgenesh tools in version 2024.2 folder
```
fgenesh_annotate.xml  
fgenesh_get_mrnas.xml  
fgenesh_check_mrna.xml  
fgenesh_renumber.xml  
fgenesh_annotate_mrnas.xml
macros.xml
```

## Fgenesh tools in version 7.2.2 folder
```
fgenesh_annotate.xml  
fgenesh_get_mrnas_gc.xml  
fgenesh_get_proteins.xml  
fgenesh_merge.xml  
fgenesh_split.xml  
fgenesh_to_genbank.xml  
macros.xml
```
