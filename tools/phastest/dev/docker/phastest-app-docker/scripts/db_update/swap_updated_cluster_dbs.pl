#!/usr/bin/perl -w

#################################################################
#
# Script to swap in new database files in place of old database
# files on the cluster head node and child nodes. Assumes the
# updated files have already been generated.
#
# David Arndt, Dec 2016
#
#################################################################

use strict;

my $CLUSTER_HOME = $ENV{PHASTEST_CLUSTER_HOME};
my $cluster_db_dir = "$CLUSTER_HOME/DB";
my $exec_dir = "$CLUSTER_HOME/scripts";
my $child_node_db_tmp_dir = '/usr/scratch/phastest/DB_tmp';
	# Directory on each child node containing updated DB files.
my $child_node_db_dir = '/usr/scratch/phastest/DB';
	# Directory on each child node containing DB files used by PHASTEST.

my $vir_dir = 'temp_vir';
my $bac_dir = 'temp_bac_select';
my $vir_database="prophage_virus.db"; # on the cluster side
my $bac_database="bacteria_all_select.db"; # on the cluster side


# Swap database files on child nodes

my $node_list = `perl $exec_dir/map_node.pl 0`;
my @lines = split("\n", $node_list);
foreach my $node_name (@lines) {
	#my $remote_cmd = 'find /usr/scratch/phastest/DB/ -mtime +5 -exec rm {} \;'; # use this if you want to clear out files older than 5 days
	#my $remote_cmd = 'ls -lt /usr/scratch/phastest/DB/';

	my $remote_cmd = "mkdir $child_node_db_dir";
	my $command = "ssh $node_name \"$remote_cmd\" ";
	print($command . "\n");
	system($command)==0 or die "Could not \'$remote_cmd\' on $node_name: $@";

	$remote_cmd = "mv $child_node_db_tmp_dir/* $child_node_db_dir";
	$command = "ssh $node_name \"$remote_cmd\" ";
	print($command . "\n");
	system($command)==0 or die "Could not \'$remote_cmd\' on $node_name: $@";
}


# Swap database files on head node

move_file("$cluster_db_dir/$vir_dir/virus_updated.db",                    "$cluster_db_dir/virus.db");
move_file("$cluster_db_dir/$vir_dir/vgenome_updated.tbl",                 "$cluster_db_dir/vgenome.tbl");
move_file("$cluster_db_dir/$vir_dir/prophage_virus*",                     "$cluster_db_dir/");
move_file("$cluster_db_dir/$bac_dir/bacteria_all_select_header_lines.db", "$cluster_db_dir/bacteria_all_select_header_lines.db");
move_file("$cluster_db_dir/$bac_dir/bacteria_all_select.*",               "$cluster_db_dir/");
	# Note: Do not move bacteria_all_select_unfiltered.db


sub move_file {
	my $from = shift;
	my $to = shift;
	
	my $cmd = "mv $from $to";
	print "$cmd\n";
	system($cmd) == 0 or die "Could not move $from to $to: $@";
}
