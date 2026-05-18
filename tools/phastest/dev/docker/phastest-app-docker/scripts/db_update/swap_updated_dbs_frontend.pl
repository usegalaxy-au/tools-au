#!/usr/bin/perl

# Script to swap updated viral and bacterial databases in place of the old ones. Assumes
# that the updated databases have already been generated. To be run from the front-end.

use strict;

# Check to see that PHASTEST_HOME environment variable is set
if ( !defined( $ENV{PHASTEST_HOME} ) ) {
    print STDERR "The PHASTEST_HOME enviroment variable is not set\n";
}
# Check to see if PHASTEST_CLUSTER_HOME environment variable is set
if ( !defined( $ENV{PHASTEST_CLUSTER_HOME} ) ) {
    print STDERR "The PHASTEST_CLUSTER_HOME enviroment variable is not set\n";
}
# Check to see if PHASTEST_CLUSTER_HOSTNAME environment variable is set
if ( !defined( $ENV{PHASTEST_CLUSTER_HOSTNAME} ) ) {
    print STDERR "The PHASTEST_CLUSTER_HOSTNAME enviroment variable is not set\n";
}

# Check to see if PHASTEST_CLUSTER_USERNAME environment variable is set
if ( !defined( $ENV{PHASTEST_CLUSTER_USERNAME} ) ) {
    print STDERR "The PHASTEST_CLUSTER_USERNAME enviroment variable is not set\n";
}

my $PHASTEST_HOME = $ENV{PHASTEST_HOME};
my $CLUSTER_HOME = $ENV{PHASTEST_CLUSTER_HOME};
my $HOSTNAME = $ENV{PHASTEST_CLUSTER_HOSTNAME};
my $USERNAME = $ENV{PHASTEST_CLUSTER_USERNAME};
my $HOST = $USERNAME . '@' . $HOSTNAME;
my $cluster_scripts_dir = "$CLUSTER_HOME/scripts/db_update";


# Pause sidekiq queue

my $ps_out = '';
$ps_out = `ps aux | grep sidekiq`;
print $ps_out;
if ($ps_out =~ /^phastest\s+(\d+)\s.*sidekiq.*project/m) {
	my $pid = $1;
	my $cmd = "kill -s USR1 $pid";
	print "$cmd\n";
	system($cmd);
} else {
	print STDERR "Could not detect sidekiq process! Abort!\n";
	exit(-1);
}


# Wait until current sidekiq jobs are done processing

while(1) {
	$ps_out = `ps aux | grep sidekiq`;
	if ($ps_out =~ /^phastest.*sidekiq.*project\s+\[(\d+) of \d+ busy\]/m) {
			# process name will look like this when running jobs are done:
			#   sidekiq 4.2.7 project [0 of 4 busy] stopping
		my $num_busy = $1;
		if ($num_busy == 0) {
			last;
		}
	} else {
		# no sidekiq process found
		last;
	}
	sleep(5);
}

# Swap databases on cluster head node and cluster child nodes

system("ssh $HOST \"perl $cluster_scripts_dir/swap_updated_cluster_dbs.pl\" ") == 0
	or die "Could not run swap_updated_cluster_dbs.pl on cluster!";

# Copy databases etc. to front-end

copy_file("$CLUSTER_HOME/DB/prophage_virus.db"); # used by scan.pl; also made available for public download
copy_file("$CLUSTER_HOME/DB/prophage_virus_header_lines.db"); # used by annotation.pl
copy_file("$CLUSTER_HOME/DB/vgenome.tbl"); # used by scan.pl
copy_file("$CLUSTER_HOME/DB/bacteria_all_select.db"); # made available for public download
copy_file("$CLUSTER_HOME/DB/bacteria_all_select_header_lines.db"); # used by annotation.pl


# Restart sidekiq

$ps_out = `ps aux | grep sidekiq`;
print $ps_out;
if ($ps_out =~ /^phastest\s+(\d+)\s.*sidekiq.*project/m) {
	my $pid = $1;
	my $cmd = "kill -9 $pid";
	print "$cmd\n";
	system($cmd) == 0 or die "Could not kill sidekiq!: $@";
} else {
	# Could not detect sidekiq process
}

chdir '/apps/phastest/project/current';
# system('bundle exec sidekiq -d -L log/sidekiq.log -C config/sidekiq.yml -e production') == 0 or die "Could not restart sidekiq!: $@";
	# seems to work, but ps output looks different


# Copy file from cluster to front-end database directory
sub copy_file {
	my $file = shift;
	
	my $cmd = "scp $HOST:$file $PHASTEST_HOME/DB/.";
	print "$cmd\n";
	system($cmd) == 0 or die "Could not copy $file";
}
