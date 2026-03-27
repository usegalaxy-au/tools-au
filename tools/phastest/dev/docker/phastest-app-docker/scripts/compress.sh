#!/bin/bash
### This script is used for compressing all the case results
### into tz format and save some space in JOBS.
###
### Since this script can take a long time to run (only ~1850 directories per hour),
### -mtime should be set below to be longer than the runtime of the second for loop to
### avoid compressing new submission directories. Second for loop might take 5–17 days to
### process for the NZ directory, depending on how many directories are there and how many
### are not compressed (none would be compressed if everything is re-run).

DIR=$PHASTEST_CLUSTER_HOME/JOBS
if [ ! -d $DIR ]; then
	echo "Error: There is no $DIR directory!"
	exit -1;
fi
cd $DIR

LIST=`ls`
for i in $LIST; do
	cd $i
	CASE_DIRS=`find ./* -maxdepth 0 -type d -mtime +30 | grep -v '.tz'` # 30 days
	for j in $CASE_DIRS; do
		if [ -d $j ]; then
			cmd="tar -czf ${j}.tz ${j}"
			echo $cmd
			`$cmd`
			
			if [ -e $j.tz ]; then
				echo tz $j.tz done
			fi
		fi
		
		if [ -e $j.tz ] && [ -d $j ] && [ ! -z $j ]; then
			cmd="rm -rf ${j}"
			echo $cmd
			`$cmd`
		fi
	done
	cd ..
done
echo "compress.sh done"

exit;
