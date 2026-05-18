#!/usr/bin/perl -w

# Filter bacterial database by calling run_cd_hit.pl through qsub. This script chooses
# a single cluster node on which to run.

use strict;
use File::Basename;
use IO::Handle;


my $input_file = $ARGV[0];
my $output_file = $ARGV[1];

if ( !defined( $ENV{PHASTEST_CLUSTER_HOME} ) ) {
    die 'The PHASTEST_CLUSTER_HOME enviroment variable is not set\n';
}
my $CLUSTER_HOME = $ENV{PHASTEST_CLUSTER_HOME};

my $scripts_dir = "$CLUSTER_HOME/scripts/db_update";
my $log_file = "$CLUSTER_HOME/DB/update.log"; # *******************

# List of nodes in order of preference to use.
my $choice1 = 'botha-w999'; # First choice.
	# Placeholder for the node formerly called botha-w11 on Botha1, with 48 CPUs. Once the
	# node is migrated to Botha10, update this line with the correct node designation.
my $choice2 = 'botha-w55'; # Second choice
my $choice3 = 'botha-w56';


##########################################################################################
# Check which nodes are alive, and choose which one to use.
##########################################################################################

my $alive = `alive`; # returns list of cluster nodes
my @nodes = split(/\n/, $alive);
my $nodes_hash = {};
foreach my $n (@nodes) {
	$nodes_hash->{$n} = 1;
}

my $node = '';
my $max_memory_MB = -1; # Max memory for CD-HIT itself
my $max_memory_MB_sched = -1; # Max memory requested from grid scheduler
my $num_threads = -1;
if (defined ($nodes_hash->{$choice1})) {
	$node = $choice1;
	$max_memory_MB = 60000; # actual RAM needed may be much less
	$num_threads = 24; # CD-HIT paper shows speed-up is only significant up to ~24 cores.
} elsif (defined ($nodes_hash->{$choice2})) {
	$node = $choice2;
	$max_memory_MB = 30000;
	$num_threads = 24;
} elsif (defined ($nodes_hash->{$choice3})) {
	$node = $choice3;
	$max_memory_MB = 30000;
	$num_threads = 24;
} else {
	# Abort
	print STDERR "Could not access any cluster nodes! Aborting!\n";
	exit(-1);
}

$max_memory_MB_sched = $max_memory_MB + 500;
	# A test on small input showed ~130 MB virual memory used by Perl on a child node for
	# running run_cd_hit.pl.


print("Running CD-HIT on $input_file on node $node...\n");
open (LOG, ">>$log_file") or die "Could not open $log_file\n";
print LOG "Running CD-HIT on $input_file on node $node...\n";


##########################################################################################
# Copy input file to cluster node -- offers ~10% speed-up.
# (Writing output file on cluster node and then copying it to the head node does not
# speed things up).
##########################################################################################

my $node_tmp_dir = '';
if ($node eq $choice1) {
	$node_tmp_dir = '/tmp'; # SSD on this particular node. A cron job deletes files older than 30 days.
} else {
	$node_tmp_dir = '/usr/scratch/phastest';
}

# create destination directory in case it is missing
my $command = "ssh $node \"mkdir -p $node_tmp_dir\" ";
print($command . "\n");
system($command)==0 or die "Could not create $node_tmp_dir on $node: $@";

# copy input file
$command = "scp $input_file $node:$node_tmp_dir";
print($command . "\n");
system($command)==0 or die "Could not copy $input_file to $node:$node_tmp_dir: $@";

my $node_input_file = $node_tmp_dir . '/' . (fileparse($input_file))[0];

##########################################################################################
# Run CD-HIT script using qsub.
##########################################################################################

if (not -x "$scripts_dir/run_cd_hit.pl") {
	system("chmod u+x $scripts_dir/run_cd_hit.pl"); # make script executable if needed
}

my $single_cmd = "$scripts_dir/run_cd_hit.pl $node_input_file $output_file $max_memory_MB $num_threads $log_file";
my $cmd = '';
my $hostname = `hostname`;
chomp($hostname);
if ($hostname eq 'botha1') {
	$cmd = "qsub -b y -pe smp $num_threads -q one.q -l h=\"$node\" -sync yes /usr/bin/perl $single_cmd";
}  elsif ($hostname eq 'botha10') {
	$cmd = "sbatch -p one.q -w $node -n 1 -c $num_threads --mem ${max_memory_MB_sched} --overcommit --wait $single_cmd";
} else {
	# Other cluster. Use its default queue.
	$cmd = "sbatch -w $node -n 1 -c $num_threads --mem ${max_memory_MB_sched} --overcommit --wait $single_cmd";
}

print LOG "$cmd\n";
LOG->flush();
close(LOG);

my $ret = system($cmd);

if ($ret != 0) {
	if ($ret == -1) {
		open (LOG, ">>$log_file");
		print LOG "filter_bac_db.pl: grid scheduler command failed. Aborting!\n";
		LOG->flush();
		close(LOG);
		exit(-1);
	} else {
		my $exitcode = $ret >> 8;
		open (LOG, ">>$log_file");
		print LOG "filter_bac_db.pl: grid scheduler returned exit status $exitcode from a failed job. Aborting!\n";
		LOG->flush();
		close(LOG);
		exit(-1);
	}
}

# Remove .clstr file created by CD-HIT.
my $clstr_file = $output_file . '.clstr';
$cmd = "rm -f $clstr_file";
print "$cmd\n";
system($cmd);

print ("Done CD-HIT!\n");
exit;
