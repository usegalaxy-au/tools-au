#!/usr/bin/perl -w

# This script:
# - Generates bacteria_all_select_header_lines.db
# - builds BLAST index files for the filtered bacterial database

use strict;

if ( !defined( $ENV{PHASTEST_CLUSTER_HOME} ) ) {
    die 'The PHASTEST_CLUSTER_HOME enviroment variable is not set\n';
}
my $CLUSTER_HOME = $ENV{PHASTEST_CLUSTER_HOME};

my $log_file = "$CLUSTER_HOME/DB/update.log";
my $tmp_dir = "/home/prion/phastest-app/DB/temp_bac_select";

if (!-d $tmp_dir){
	print STDERR "There is no $tmp_dir, program exit!\n";
	exit(-1);
}
chdir $tmp_dir;

if (!(-e 'bacteria_all_select_filtered.db')) {
	print STDERR "There is no bacteria_all_select_filtered.db, program exit!\n";
	exit(-1);
}

system("echo 'renaming bacteria_all_select_filtered.db to bacteria_all_select.db'");
system("mv bacteria_all_select_filtered.db bacteria_all_select.db");

system("echo 'make bacteria_all_select_header_lines.db'");
system("grep '>' bacteria_all_select.db > bacteria_all_select_header_lines.db");

system("echo 'run makeblastdb'");
system("makeblastdb -in bacteria_all_select.db -parse_seqids -dbtype prot >> $log_file");

system("echo 'done!'");
