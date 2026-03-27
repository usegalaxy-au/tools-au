#!/usr/bin/perl -w

##########################################################################################
#
# Combines viral gene sequences from NCBI (virus.db) and Srividhya et al. (prophage.db)
# into the final viral database (prophage_virus.db). Also makes
# prophage_virus_header_lines.db and generates BLAST indices.
#
# The reference for Srividhya et al. is:
# Srividhya KV, Rao GV, Raghavenderan L, Mehta P, Prilusky J, Sankarnarayanan M, Sussman
# JL, Krishnasswamy S. Database and comparative identification of prophages. Lec. Notes
# Control Informat. Sci. 2006;344:863-868.
#
##########################################################################################

use strict;

if ( !defined( $ENV{PHASTEST_CLUSTER_HOME} ) ) {
    die 'The PHASTEST_CLUSTER_HOME enviroment variable is not set\n';
}
my $CLUSTER_HOME = $ENV{PHASTEST_CLUSTER_HOME};

my $db_dir = "$CLUSTER_HOME/DB";

print `date`;
my $start_time = time;
if (!(-e "$db_dir/temp_vir/virus_updated.db")){
	print "$db_dir/temp_vir/virus_updated.db not exist!\n";
	exit(-1);
}
system("cat $db_dir/temp_pro/prophage.db  $db_dir/temp_vir/virus_updated.db > $db_dir/temp_vir/prophage_virus.db");

chdir "$db_dir/temp_vir";
my $error_flag = 0;
if (-s "prophage_virus.db"){
	print "Make header lines file\n";
	system("grep '>' prophage_virus.db > prophage_virus_header_lines.db");
	
	system("echo 'run makeblastdb'");
	system("makeblastdb -in prophage_virus.db -dbtype prot");	
}else{
	print "prophage_virus.db  has no content. Please check!\n";
	$error_flag = 1;
}
my $end_time = time;
my $time = $end_time - $start_time;
my $min = int($time /60);
my $sec = $time % 60;
print "running time = $min min $sec sec\n";
print "Program exit!\n\n\n";
if ($error_flag ==1){
	exit(-1);
}
exit;
