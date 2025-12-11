#!/usr/bin/perl -w

# Run CD-HIT on a single cluster node to filter a sequence database. Submit this script
# to the grid scheduler.

use strict;
use IO::Handle;

my $t1 = time;

print `hostname`;


my $input_file = $ARGV[0];
my $output_file = $ARGV[1];
my $max_memory_MB = $ARGV[2];
my $num_cpus = $ARGV[3];

my $log_file = '';
if (defined($ARGV[4])) {
	$log_file = $ARGV[4];
}


my $command = "/home/prion/cdhit-master/cd-hit -i $input_file -o $output_file -c 0.7 -M $max_memory_MB -T $num_cpus";

if ($log_file ne '') {
	open (LOG, ">>$log_file") or die "Could not open $log_file: $!\n";;
	print LOG "$command\n";
	close(LOG)
} else {
	system("echo '$command'");
}


my $ret = system("$command > /dev/null");
	# CD-HIT writes a lot of output to STDOUT. Redirecting to /dev/null is efficient, but
	# saving the output (with simple methods) increases run time significantly.
	#
	# my $ret = system("$command >> $log_file 2>&1");
	#  takes ~10 times longer
	#
	# my $ret = system("$command");
	#  grid scheduler will write STDOUT to a file on disk. Takes ~5 times longer.


if ($ret != 0) {
	if ($ret == -1) {
		if ($log_file ne '') {
			open (LOG, ">>$log_file");
			print LOG "run_cd_hit.pl: CD-HIT failed to run\n";
			LOG->flush();
			close(LOG)
		} else {
			system("echo 'run_cd_hit.pl: CD-HIT failed to run'");
		}
		exit(78);
	} else {
		my $exitcode = $ret >> 8;
		if ($log_file ne '') {
			open (LOG, ">>$log_file");
			print LOG "run_cd_hit.pl: CD-HIT failed with exit status $exitcode $ret\n";
			LOG->flush();
			close(LOG)
		} else {
			system("echo 'run_cd_hit.pl: CD-HIT failed with exit status $exitcode $ret yeah'");
		}
		exit($exitcode);
	}
}

my $runtime_str = "Run time = ". (time - $t1)." seconds\n";
print $runtime_str;
open (LOG, ">>$log_file");
print LOG $runtime_str;
close(LOG);

exit(0);
