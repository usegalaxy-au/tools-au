## Fgenesh is a licensed genome annotation tool. 
Some fgenesh tools come in two version: an older version (v7.2.2) and a newer one (v2024.2). Each version of the tool has different parameters.

## Fgenesh Databases

The par file contains the parameter used by fgenesh annotate tool. The par files come with the fgenesh tools and stored in custom-indices/fgenesh/params folder.
```
  - mammals.par (v7.2.2) 
  - non_mamma.par (v7.2.2)
  - mammals_v2024.par (v2024.2)
  - non_mamm_v2024.par (v2024.2)
```

Gene matrix file contains the predicted gene model of a species, and it comes with the fgenesh tools and stored in custom-indices/fgenesh/matrix. Each species has its own .dat file. There is a total of 522 dat files.
```
Absidia_idahoensis.mpar.dat
Hypocrella_siamensis.mpar.dat
Metarhizium.mpar.dat
Melampsora_larici-populina.mpar.dat
Danio_rerio_3.mpar.dat
Cladophialophora.mpar.dat
...
```

Custom Non-redundant database. Currently, the Fgenesh annotate tool supports the following species:
```
Caernorhabditis elegans (2023-09-12)
Chelonia mydas (2023-09-12)
Fungi (2023-09-12)
Metazoa (2023-09-12)
TSI animals (2023-09-12)
Viridiplantae (2023-09-12)
```
Fungi, Metazoa and Viridiplantae were custom-made following the [instructions here](https://github.com/mthang/custom_nr_db)

## Setup databases on Galaxy

On Galaxy Production/Dev.
1) Fgenesh Docker container will be installed on Galaxy automatically.
2) setup the Non redundant NCBI DB , gene matrix and Fgenesh parameters on Galaxy manually. Folder /mnt/galaxy/local_tools/db
3) move all the loc files to the tool-data folder under the Galaxy root directory.
4) update the db path in all loc files
5) add the wrapper to local_tool_conf.xml (dev) or tool_conf.xml (production)
6) create a customize tool_data_table_conf.xml in /mnt/galaxy/local_tools/db folder
7) append the tool_data_table_conf.xml to tool_data_table_config_path in galaxy.xml

On local Galaxy.
1) setup the authentication docker file under .docker/config.json only if running fgenesh on a local galaxy instance - optional.
2) setup the Non redundant NCBI DB , gene matrix and Fgenesh parameters on Galaxy manually in folder custom-indices/fgenesh
  - Non Redundant NCBI DB in custom-indices/fgenesh/nr
  - Gene matrix in custom-indices/fgenesh/matrix
  - Parameter files (par) in custom-indices/fgenesh/params
4) move all manually made loc files (i.e fgenesh_nr.loc, fgenesh_matrix.loc, fgenesh_db.loc and fgenesh_db_v2024.loc) to the tool/tool-data folder on GA.
5) Ensure the db path in all loc files are pointing to tool/tool-data
6) add the wrapper to local_tool_conf.xml (dev) or tool_conf.xml (production)
7) create a customize tool_data_table_conf.xml in /mnt/galaxy/local_tools/db folder (dev) or custom-indices folder (production). 
8) append the tool_data_table_conf.xml to tool_data_table_config_path in galaxy.xml

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
