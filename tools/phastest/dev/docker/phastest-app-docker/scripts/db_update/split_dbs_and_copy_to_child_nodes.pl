#!/usr/bin/perl -w

#################################################################
#
# Script to split the target BLAST DBs into smaller DBs, and then
# distribute them to the child nodes on the cluster. The files
# are copied to a temporary directory only; another script will
# replace the old database files with the new ones on each node.
#
# David Arndt, Jan 2016
#
#################################################################

use strict;

my $sha_bin = 'sha1sum';

if ( !defined( $ENV{PHASTEST_CLUSTER_HOME} ) ) {
    die 'The PHASTEST_CLUSTER_HOME enviroment variable is not set\n';
}
my $CLUSTER_HOME = $ENV{PHASTEST_CLUSTER_HOME};
my $cluster_scripts_dir = "$CLUSTER_HOME/scripts";
my $cluster_db_dir = "$CLUSTER_HOME/DB";
my $child_node_db_dir = '/usr/scratch/phastest/DB_tmp';
	# Location on each child node in which to store copies of DB parts.

my $vir_dir = 'temp_vir';
my $bac_dir = 'temp_bac_select';
my $vir_database="prophage_virus.db"; # on the cluster side
my $bac_database="bacteria_all_select.db"; # on the cluster side

my $num_parts = 8; # number of parts into which to split each DB
my $split_vir_db = 0; # boolean
my $split_bac_db = 1; # boolean

# Process viral DB.
process_db($split_vir_db, $vir_dir, $vir_database);

# Process bacterial DB.
process_db($split_bac_db, $bac_dir, $bac_database);
	

# Split, index, and copy a database
sub process_db {
	my $split_db = shift;
	my $dir = shift;
	my $db_name = shift;

	if ($split_db) {
		# Split the database into parts

		my $cmd = "$cluster_scripts_dir/db_update/split_fasta_file.pl $num_parts $cluster_db_dir/$dir/$db_name";
		print($cmd . "\n");
		system($cmd);

		# Create indices and copy DB parts to nodes
		for (my $db_part_id = 1; $db_part_id <= $num_parts; $db_part_id++) {

			my $db_part_name = $db_name . ".part" . $db_part_id;

			# Create BLAST indices for the parts
			my $command = "makeblastdb -in $cluster_db_dir/$dir/$db_part_name -parse_seqids -dbtype prot";
			print($command . "\n");
			system($command)==0 or die "Could not create BLAST indices for $db_part_name: $@";
			
			# Obtain list of nodes to which the given database part is assigned.
			my $node_list = `perl $cluster_scripts_dir/map_node.pl $db_part_id`;
			my @lines = split("\n", $node_list);
			foreach my $node_name (@lines) {
				copy_to_node($db_part_name, $dir, $node_name);
			}
			
		}
	} else {
		# Do not split the target database, but still copy the DB and its index files to
		# every node. We assume that the indices of the main database file already exist.
		my $node_list = `perl $cluster_scripts_dir/map_node.pl 0`;
		my @lines = split("\n", $node_list);
		foreach my $node_name (@lines) {
			copy_to_node($db_name, $dir, $node_name);
		}
	}
}


sub copy_to_node {
	my $db_part_name = shift;
	my $dir_name = shift; # name of directory containing database files on head node
	my $node_name = shift;
	
	my $sha_head = '';
	my $sha_child = '';
	my $stat_child = '';
	my $copy = 0;
	
	# Check whether the node is even up.
	my @alive = `alive`;
	my $alive_hash = {};
	foreach my $node (@alive) {
		chomp($node);
		$alive_hash->{$node} = 1;
	}
	if (!exists $alive_hash->{$node_name}) {
		print STDERR "The node $node_name is down. Skipping.\n";
		return;
	}

	# create destination directory in case it is missing
	my $command = "ssh $node_name \"mkdir -p $child_node_db_dir\" ";
	print($command . "\n");
	system($command)==0 or die "Could not create $child_node_db_dir on $node_name: $@";
	
	# check whether database part is already on the child node
	$copy = 0;
	$sha_head = `$sha_bin $cluster_db_dir/$dir_name/$db_part_name`;
	$sha_head = substr($sha_head, 0, 40);
	$stat_child = `ssh $node_name stat $child_node_db_dir/$db_part_name`;
	if (!($stat_child =~ 'No such file or directory')) {
		# file exists on child node
		$sha_child = `ssh $node_name $sha_bin $child_node_db_dir/$db_part_name`;
		$sha_child = substr($sha_child, 0, 40);
		if ($sha_head ne $sha_child) {
			# files differ
			$copy = 1;
		}
	} else {
		$copy = 1;
	}
	
	# copy database part
	if ($copy) {
		$command = "scp $cluster_db_dir/$dir_name/$db_part_name $node_name:$child_node_db_dir";
		print($command . "\n");
		system($command)==0 or die "Could not copy $db_part_name to $node_name:$child_node_db_dir: $@";
	
		# verify
		$sha_child = `ssh $node_name $sha_bin $child_node_db_dir/$db_part_name`;
		$sha_child = substr($sha_child, 0, 40);
	# 	print "$sha_bin $cluster_db_dir/$dir_name/$db_part_name\n";
	# 	print "ssh $node_name $sha_bin $child_node_db_dir/$db_part_name\n";
	# 	print `ssh $node_name ls -ld $child_node_db_dir/$db_part_name`;
		if ($sha_head ne $sha_child) {
			print STDERR "INCONSISTENT: $node_name:$child_node_db_dir/$db_part_name\n";
			exit(1);
	# 		print STDERR "  $sha_head\n";
	# 		print STDERR "  $sha_child\n";
		}
	} else {
		print("Skip $node_name:$child_node_db_dir/$db_part_name\n");
	}
	
	# copy indices
	opendir(DIR, "$cluster_db_dir/$dir_name");
	my @files = readdir(DIR);
	closedir(DIR);
	foreach my $file (@files) {
		if ($file =~ m/^$db_part_name(\.\d+)?\.(phr|pin|pog|psd|psi|psq)$/) {
		
			# check whether index file is already on the child node
			$copy = 0;
			$sha_head = `$sha_bin $cluster_db_dir/$dir_name/$file`;
			$sha_head = substr($sha_head, 0, 40);
			$stat_child = `ssh $node_name stat $child_node_db_dir/$file`;
			if (!($stat_child =~ 'No such file or directory')) {
				# file exists on child node
				$sha_child = `ssh $node_name $sha_bin $child_node_db_dir/$file`;
				$sha_child = substr($sha_child, 0, 40);
				if ($sha_head ne $sha_child) {
					# files differ
					$copy = 1;
				}
			} else {
				$copy = 1;
			}
			
			if ($copy) {
				$command = "scp $cluster_db_dir/$dir_name/$file $node_name:$child_node_db_dir";
				print($command . "\n");
				system($command)==0 or die "Could not copy indices for $db_part_name to $node_name:$child_node_db_dir: $@";
				
				# verify
				$sha_child = `ssh $node_name $sha_bin $child_node_db_dir/$file`;
				$sha_child = substr($sha_child, 0, 40);
				if ($sha_head ne $sha_child) {
					print STDERR "INCONSISTENT: $node_name:$child_node_db_dir/$file\n";
					exit(1);
	# 				print STDERR "  $sha_head\n";
	# 				print STDERR "  $sha_child\n";
				}
			} else {
				print("Skip $node_name:$child_node_db_dir/$file\n");
			}
		}
	}
	
}
