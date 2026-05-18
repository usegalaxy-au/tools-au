# Run either an SSH or SCP command, trying multiple times in case of failure, producing
# error if applicable, and printing the runtime.
# 
# First argument: 'ssh' or 'scp'
# Subsequent arguments: arguments to ssh or scp
function run_over_ssh {
	cmd=$1
	script_name=$(basename $0) # name of calling script
	pre_time=$(date +"%s")
	
	i="0"
	failed="0"
	full_cmd=""
	while [ $i -lt $ssh_tries ]; do
# 		if [ "$cmd" = "ssh" ]; then
# 			full_cmd="ssh $2 $3"
# 			ssh $2 $3
# 		else # scp
# 			full_cmd="scp $2 $3"
# 			scp $2 $3
# 		fi
		full_cmd="$cmd $2 $3"
		$cmd $2 $3
		
		if [ "$?" -eq "0" ]; then
			failed="0"
			break # successful
		else
			failed="1"
			if [ $i -lt $(expr $ssh_tries - 1) ]; then
				sleep $ssh_wait
			fi
		fi
		i=$[$i+1]
	done
	
	if [ "$failed" -eq "1" ]; then
		echo "$script_name: '$full_cmd' failed!"
		exit 1
	fi
	
	post_time=$(date +"%s")
	elapsed=$((post_time-pre_time))
	echo "$script_name: '$full_cmd' took $elapsed sec"
}
