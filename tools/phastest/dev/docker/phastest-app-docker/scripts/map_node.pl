#!/usr/bin/perl -w

# Given a database part id (integer 1 or higher), returns a list (one per line) of cluster
# nodes to which the database part is assigned. If given 0, returns a list of all cluster
# nodes.
#
# This script is used to specialize the smaller cluster nodes so they will run BLAST
# against particular database parts only, with the hope of reducing memory swapping
# overhead.

use strict;

my $number_of_db_parts = 8;

# Lists of cluster nodes by size.
#   4-core nodes: Assign 2 of 8 DB parts to each of these nodes.
#   8-core nodes: Assign 4 of 8 DB parts to each of these nodes.
#   larger nodes: Assign all DB parts to each of these nodes.
my @four_core_node_nums = (
	
	);
my @eight_core_node_nums = (
	01, 02, 03, 04
	);
my @large_node_nums = (
	
	);

my $db_part_id = $ARGV[0];

# Error checking:
if ($#ARGV == -1) {
	print "Error! No input arguments entered!\n";
	exit(-1);
}
if ($db_part_id < 0 || $db_part_id > $number_of_db_parts) {
	print STDERR "Invalid database part id: $db_part_id\n";
	exit(1);
}

if ($db_part_id == 0) {
	# Print all nodes
	for (my $i = 0; $i < scalar(@four_core_node_nums); $i++) {
		print 'botha-w' . $four_core_node_nums[$i] . "\n";
	}
	for (my $i = 0; $i < scalar(@eight_core_node_nums); $i++) {
		print 'botha-w' . $eight_core_node_nums[$i] . "\n";
	}
	for (my $i = 0; $i < scalar(@large_node_nums); $i++) {
		print 'botha-w' . $large_node_nums[$i] . "\n";
	}
} else {
	# Iterate through 4-core nodes, such that, depending on $db_part_id, a particular subset
	# of 1/4th of the 4-core nodes will be selected and printed.
	#
	# Map $db_part_id and $i to [0, 3] as follows and match:
	#
	# $db_part_id: 1 2 3 4 5 6 7 8
	#              v v v v v v v v map
	#              0 1 2 3 0 1 2 3
	#
	#          $i: 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 ...
	#              v v v v v v v v v v  v  v  v  v  v  v
	#              0 1 2 3 0 1 2 3 0 1  2  3  0  1  2  3 ...
	for (my $i = 0; $i < scalar(@four_core_node_nums); $i++) {
		if ( (($db_part_id - 1) % ($number_of_db_parts/2)) == ($i % ($number_of_db_parts/2)) ) {
			print 'botha-w' . $four_core_node_nums[$i] . "\n";
		}
	}

	# Iterate through 8-core nodes, such that, depending on $db_part_id, a particular subset
	# of half of the 8-core nodes will be selected and printed.
	for (my $i = 0; $i < scalar(@eight_core_node_nums); $i++) {
		if ( (($db_part_id - 1) % ($number_of_db_parts/4)) == ($i % ($number_of_db_parts/4)) ) {
			print 'botha-w' . $eight_core_node_nums[$i] . "\n";
		}
	}

	# Print all large cluster nodes.
	for (my $i = 0; $i < scalar(@large_node_nums); $i++) {
		print 'botha-w' . $large_node_nums[$i] . "\n";
	}
}
