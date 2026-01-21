#!/usr/bin/perl -w

# Initial phase of viral and bacterial database updates to be run on back-end cluster.

use IO::Handle;

use strict;

if ( !defined( $ENV{PHASTEST_CLUSTER_HOME} ) ) {
    die 'The PHASTEST_CLUSTER_HOME enviroment variable is not set\n';
}
my $CLUSTER_HOME = $ENV{PHASTEST_CLUSTER_HOME};

my $exec_dir = "$CLUSTER_HOME/scripts/db_update";
my $DB_dir = "$CLUSTER_HOME/DB";

my $update_logfile = "$DB_dir/update.log";
system("echo 'Run update_database_back_end.pl' > $update_logfile");
my $date = `date`;
system("echo '$date' >> $update_logfile");

run_command("perl $exec_dir/make_virus_database.pl", "make_virus_database.pl",
		"$DB_dir/make_virus_database.log", $update_logfile);

run_command("perl $exec_dir/make_prophage_virus_db.pl", "make_prophage_virus_db.pl",
		"$DB_dir/make_prophage_virus_db.log", $update_logfile);

run_command("perl $exec_dir/make_bac_select_database.pl", "make_bac_select_database.pl",
		"$DB_dir/make_bac_select_database.log", $update_logfile);

system("echo 'update_database_back_end.pl finished successfully' >> $update_logfile");
exit;


sub run_command {
	my ($command, $program_name, $command_log_file, $general_log_file) = (@_);
		# $program_name just needs to be a human-readable name.
	
	system("echo '$command' >> $general_log_file");
	my $ret = system("$command >> $command_log_file 2>&1");
	if ($ret != 0) {
		my $err = '';
		if ($ret == -1) {
			$err = "ERROR: $program_name failed to run! Aborting.";
		} else {
			my $exitcode = $ret >> 8;
			$err = "$program_name failed with exit status $exitcode! Aborting.";
		}
		open (LOG, ">>$general_log_file") || die "Could not open file $general_log_file to write error ($err): $!\n";
		print LOG "ERROR: $err\n";
		LOG->flush();
		close(LOG);
		print STDERR "ERROR: $err\n";
		exit(-1);
	}
}
