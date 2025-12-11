#!/usr/bin/perl -w

# this program will initiate all the sub programs to finish 
# phage finder and filter's jobs.

# This version of the phastest.pl is designed to be ran within the docker cluster.
# It does not rely on any outside cluster (and by extension, any `ssh` or `scp`) to complete jobs.

use Cwd;
use Mail::Sendmail;
use IO::Handle;
use POSIX (); # Use () to not export functions so that getcwd does not conflict with function of same name from Cwd.
use sigtrap 'handler', \&handle_term, 'TERM'; # When receive TERM signal, call handle_term subroutine.
use DBI;

$SIG{INT} = \&handle_term; # When receive INT signal, call handle_term subroutine.

# ARGUMENTS - flag (-g or -s or -c), accession number (or identifier), annotation mode (-l or -d)
#   -g = GenBank input file
#   -s = single FASTA sequence only
#   -c = multi-FASTA file of several contigs
#	-l = 'lite' annotation mode, using Swissprot database
#	-d = 'deep' annotation mode, using local bacteria_all_select database (PHAST-BSD)

my $flag = $ARGV[0];
my $num = $ARGV[1];
my $mode = $ARGV[2];
my $anno_flag = 1;	# 0 if prophage region only, 1 for annotating all proteins in genome.

unless (defined($mode)) {
	print "Annotation mode not given! Defaulting to lite annotation mode\n";
	$mode = "-l";
}

unless (defined($anno_flag)) {
	print "Annotation flag not given! Defaulting to genome-wide annotation\n";
	$anno_flag = 1;
}

print "Running PHASTEST\n";
print "Job ID: $num\n";

# Check to see that PHASTEST_HOME environment variable is set
if ( !defined( $ENV{PHASTEST_HOME} ) ) {
    error_exit($num, 'The PHASTEST_HOME enviroment variable is not set\n')
}

my $PHASTEST_HOME = $ENV{PHASTEST_HOME};
my $jobs_dir = "$PHASTEST_HOME/JOBS";
my $scripts_dir = "$PHASTEST_HOME/scripts";  # dir of executables.
my $database_dir = "$PHASTEST_HOME/DB";

our $CURRENT_PID = $$;

my $bac_database="swissprot.db";
my $bac_header_database="swissprot_header.db";

if ($mode eq "-d") {
	$bac_database = "bacteria_all_select.db";
	$bac_header_database = "bacteria_all_select_header_lines.db";
}

my $cluster_head_bac_database = "$database_dir/$bac_database"; # Uses path on head node
my $cluster_child_bac_database = "$database_dir/$bac_database"; # Uses path on each child node
# my $local_bac_database = "$sub_program_dir/phage_finder/DB/$bac_database";
my $local_bac_header_database = "$database_dir/$bac_header_database";

my $virus_database="prophage_virus.db"; # virus db name
my $virus_header_database= "prophage_virus_header_lines.db";

my $cluster_head_virus_database = "$database_dir/$virus_database"; # Uses path on head node
my $cluster_child_virus_database = "$database_dir/$virus_database"; # Uses path on each child node

my $local_virus_header_database = "$database_dir/$virus_header_database";
my $email_receiver="yongjiel\@ualberta.ca";# when cluster side not working, the receiver of the mail
my $email_sender="phast\@phast.wishartlab.com";#when cluster side not working, the sender of the mail

# Set process group ID (PGID) for the original phastest.pl process. We use the current
# process id ($$) as the PGID.
#
# The reason is that when Sidekiq times out a job, it will terminate all processes with
# the same PGID as the phastest.pl process it spawned. So we want to ensure that each
# original phastest.pl process will have its own distinct PGID. (If we do not set the PGID,
# then the PGID is inherited from the Sidekiq process, so all original phastest.pl
# processes will have the same PGID, and so if one job times out then all running jobs
# will be terminated. Sidekiq would also terminate itself, which is not what we want!)
#
# Note that below we also fork this phastest.pl process, which results in forked instances
# of phastest.pl that have their own new PGIDs. To ensure that these processes are
# properly terminated when there is a timeout, when the parent phastest.pl process receives
# a TERM signal, the handle_term() subroutine below is called to terminate all forked
# processes and their child processes.
setpgrp(0, $$) || do {
	open (LOG, ">>$log_file") || die "Could not open file $log_file to say setpgrp failed: $!\n";
	print LOG "setpgrp failed for main phastest.pl process!\n";
	LOG->flush();
	close(LOG);
	die "Cannot do setpgrp\n";
	};
my @children=(); # Array of PIDs of processes forked from the original phastest.pl process.


my $start_time = time;
my $time;

my @running_array = ( "$jobs_dir/running1.txt",  "$jobs_dir/running2.txt", "$jobs_dir/running3.txt"); # if update this array, update it in Results.cgi either

my $phage_finder_tolerate_time=720*60 ; #sec
my $tRNAscan_tolerate_time=360*60 ; #sec
our $running_case_file = find_running_case_file(\@running_array);

# Create job directory if none exists.
system("mkdir -p $jobs_dir/$num") if (! -d "$jobs_dir/$num");

# If we are running a contig job, create _original.fna if it does not already exists.
if ($flag eq '-c') {
	system("mv $jobs_dir/$num/$num.fna $jobs_dir/$num/$num\_original.fna") if (! -e "$jobs_dir/$num/$num\_original.fna");
}

my $log_file="$jobs_dir/$num/$num.log";
my $ti = `date`; $ti=~s/\n//;
system("echo '\nJob start running ,time=$ti' >> $log_file");
system("echo 'perl $scripts_dir/phastest.pl  $ARGV[0] $ARGV[1] $ARGV[2]' >> $log_file" );
my $space = `df -h $jobs_dir`; 
my ($available_space) = $space =~ /(?:.*?\n)\S+\s+\S+\s+\S+\s+(\S+)/s;
print "Available space of $jobs_dir is $available_space\n";

system("echo 'Job $num is running.' >>$log_file" );
unlink "$jobs_dir/$num/fail.txt" if (-e "$jobs_dir/$num/fail.txt");
unlink "$jobs_dir/$num/success.txt" if (-e "$jobs_dir/$num/success.txt");
unlink "$jobs_dir/$num/$num.done" if (-e "$jobs_dir/$num/$num.done");

my $process_file ="$num.process";
my $process='';
my $process_fail='';

chdir "$jobs_dir/$num";

if($flag eq '-g') {# we have GBK file
	print "Handle gbk file...\n";
	system("echo 'Start -g flag ' >> $log_file");

	# Download .gbk file if the .gbk doesn't exist, or if the .gbk is faulty.
	if (! -s "$num.gbk" || `cat $num.gbk` =~ /\+Error%3A\+CEFetchPApplication%3A%3Aproxy_stream\(\)/) {
		system("echo 'Downloading gbk file from NCBI' >> $log_file");
		get_gbk_file($num, $log_file, "..");
			
		# Retrieve contigs if the GBK file is whole-genome shotgun sequence.
		system("perl $scripts_dir/retrieve_contig_parallel.pl $num  $jobs_dir/$num 2>&1|cat >> $log_file.2") if (`cat $num.gbk` =~ /WGS\s+(\S+)\-(\S+)/);
	}
	
	if (-s "$num.gbk"){
		my $has_translation = check_gbk_file("$num.gbk", $num);

		if (-e "$num\_master_record.gbk") {
			# Generate contig location data.
			my $comm = "perl $scripts_dir/gbk2contigs.pl $num";
			system("echo '$comm' >> $log_file ");
			system("$comm 2>&1 >> $log_file");
		}

		if ($has_translation == 0){
			system("echo '$num.gbk has no translation area, change it into DNA sequence only' >> $log_file");
			$flag = '-s';
			system("Changing flag, flag = $flag' >> $log_file");
		}
	}
	else {
		$process = "Failed to retrieve .gbk file. Accession number may be invalid, or NCBI may be unavailable.\n";
		$process_fail = $process;
		check_success_fail_exit($num, "$num.gbk", $process, $process_fail, $process_fail);
	}
}

if ($flag eq '-s' or $flag eq '-c'){ # have fasta seq or contigs file, so use prodigal or FragGeneScan to predict ORF and create .ppt .fna .faa files;
	print "Handle fna file ...\n";
	# With contig file input, file will be named as e.g. ZZ_57088e1f0c_filtered.fna instead of ZZ_57088e1f0c.fna
	my $postfix = '';
	if ($flag eq '-c') {
		# Check valid headers for each contig sections.
		my $valid_headers = check_contig_headers("$num\_original.fna");
		if ($valid_headers == 0) {
			$process = "Invalid contig header line detected! <br/>Please make sure your input file adheres to FASTA format.";
			$process_fail = $process;
			check_success_fail_exit($num, "$num.fna", $process, $process_fail, $process_fail);
		}

		# move the file generation back from Rails front end to here back end.
		my $cm = "perl $scripts_dir/make_contig_position.pl $num\_original.fna";
		system("echo '$cm' >> $log_file ");
		system("$cm 2>&1 >> $log_file");

		system("echo 'Regenerate fna file....' >> $log_file");
		if (-s "$num\_original.fna"){
			# generate an entire genome fna file
			open(OUT,  "> $num.fna") or die "Cannot generate $num.fna. $!";
			my $fna_header = find_common_element("$num\_contig_positions.txt");
			print OUT ">gi|00000000|ref|NC_000000| $fna_header\n";
			print OUT `grep -v '>' $num\_original.fna`;
			close OUT;
		}
	}
	elsif ($flag eq '-s') {
		# If the first line of the .fna file does not start with a gi number, create a fixed version.
		if ((`head -n 1 $num.fna` =~ /^>gi\|\d+\|ref\|\S+\|/) == 0) {
			system("mv $num.fna $num\_original.fna");
			open(OUT, "> $num.fna") or die "Cannot generate $num.fna. $!";
			print OUT ">gi|00000000|ref|NC_000000| " . substr(`head -n 1 $num\_original.fna`, 1);
			print OUT `grep -v '>' $num\_original.fna`;
			close OUT;
		}
	}

	if (!-s "$num$postfix.fna"){
		$process=	"There is no DNA sequence in .fna file. Program terminated!\n";
		$process_fail=$process;
		check_success_fail_exit($num, "DNA_no_seq_in_fna_file", $process, $process_fail, $process_fail);
	}
	
	fix_fna_lines("$num.fna");
	if ($flag eq '-c') {
		fix_fna_lines("$num$postfix.fna");
	}
	
	if ($flag eq '-s') {
		# call prodigal with single FASTA sequence
		
		system("echo XXXXX running prodigal XXXXXX >> $log_file");
		print "Running Prodigal on $num.fna ...\n";
		my $start_prodigal_time = time;
		$time = $start_prodigal_time - $start_time;
		system("echo 'Start prodigal at $time sec' >> $log_file");

		$process="prodigal-2.6.3 is running...\n";
		write_process_file($process_file,$process );

		system("echo XXXXX running prodigal XXXXXX >> $log_file");
		my $prodigal = "$jobs_dir/$num";
		my $cm = "perl $scripts_dir/call_prodigal.pl $num";
		system("echo '$cm' >> $log_file");
		my $ret = system("$cm >> $log_file 2>&1");
		if ($ret != 0) {
			if ($ret == -1) {
				my $msg = "call_prodigal.pl failed to run";
				open (LOG, ">>$log_file");
				print LOG "$msg\n";
				LOG->flush();
				close(LOG);
				error_exit($num, 'Error running prodigal')
			} else {
				my $exitcode = $ret >> 8;
				my $msg = "call_prodigal.pl failed with exit status $exitcode";
				open (LOG, ">>$log_file");
				print LOG "$msg\n";
				LOG->flush();
				close(LOG);
				error_exit($num, 'Error running prodigal')
			}
		}
	
		system("echo 'XXXXX running prodigal finished XXXXXX\n' >> $log_file");
		my $end_prodigal_time = time;
		my $prodigal_time = $end_prodigal_time - $start_prodigal_time;
		system("echo 'prodigal run time = $prodigal_time sec' >> $log_file");
		$process_fail = "prodigal failed!\n";
		$process = "prodigal-2.6.3 is done!\n";
		check_success_fail_exit($num, "$num.predict", $process, $process_fail, "prodigal failed!");
	} elsif ($flag eq '-c') {
		print "Running FragGeneScan on $num.fna ...\n";
		system("echo XXXXX running FragGeneScan XXXXXX >> $log_file");
		my $start_fraggenescan_time = time;
		$time = $start_fraggenescan_time - $start_time;
		system("echo 'Start FragGeneScan at $time sec' >> $log_file");

		$process="FragGeneScan is running...\n";
		write_process_file($process_file,$process );

		system("echo XXXXX parallel running FragGeneScan XXXXXX >> $log_file");
		my $cm = "$scripts_dir/call_fraggenescan.pl $num $jobs_dir/$num/$num\_original.fna $jobs_dir/$num/$num\_contig_positions.txt $log_file";
		system("echo '$cm' >> $log_file");
		my $ret = system("$cm");
		if ($ret != 0) {
			if ($ret == -1) {
				my $msg = "call_fraggenescan.pl failed to run";
				open (LOG, ">>$log_file");
				print LOG "$msg\n";
				LOG->flush();
				close(LOG);
				error_exit($num, 'Error running FragGeneScan')
			} else {
				my $exitcode = $ret >> 8;
				my $msg = "call_fraggenescan.pl failed with exit status $exitcode";
				open (LOG, ">>$log_file");
				print LOG "$msg\n";
				LOG->flush();
				close(LOG);
				error_exit($num, 'Error running FragGeneScan')
			}
		}
		system("echo 'XXXXX running FragGeneScan finished XXXXXX\n' >> $log_file");
		my $end_fraggenescan_time = time;
		my $fraggenescan_time = $end_fraggenescan_time - $start_fraggenescan_time;
		system("echo 'FragGeneScan run time = $fraggenescan_time sec' >> $log_file");
		$process_fail = "FragGeneScan failed!\n";
		$process = "FragGeneScan is done!\n";
		check_success_fail_exit($num, "$num.predict", $process, $process_fail, "FragGeneScan failed!");
	}
	
	my $ppt_start_time = time;
	write_process_file($process_file, "Generating ptt file...\n");
	print "Generating ptt file ...\n";
	$cm = "perl $scripts_dir/change_to_ptt_format.pl $num.fna $num.predict  $num.ptt";
	system("echo '$cm' >> $log_file");
	system("$cm");
	$process_fail = "Ptt file was not generated! Job failed!\n";
	$process = "Ptt file has been generated!\n";
	check_success_fail_exit($num, "$num.ptt", $process, $process_fail, "No coding sequence (CDS) was detected! Please check your GenBank or FASTA sequence file! <br/>If you submitted a GenBank file, try submitting a FASTA file instead.");
	my $ptt_end_time = time;
	$time = $ptt_end_time - $ppt_start_time;
	system("echo 'Generating ptt file took $time sec' >> $log_file");

	my $faa_start_time = time;
	write_process_file($process_file, "Generating faa file...\n");
	print "Generating faa file ...\n";
	system("perl $scripts_dir/change_to_protein_seq.pl $num.fna $num.predict $num.faa");
	$process_fail = "Faa file was not generated! Job failed!\n";
	$process = "Faa file has been generated!\n";
	check_success_fail_exit($num, "$num.faa", $process, $process_fail, "No coding sequence (CDS) was detected! Please check your GenBank or FASTA sequence file! <br/>If you submitted a GenBank file, try submitting a FASTA file instead.");
	my $faa_end_time = time;
	$time = $faa_end_time - $faa_start_time;
	system("echo 'Generating faa file took $time sec' >> $log_file");
	
}else{ # we have gi number or accession number or GBK file
	write_process_file($process_file, "Generating fna file...\n");
	my $fna_start_time = time;
	if (!(-s "$num.fna")){
		print "Generating fna file from gbk ...\n";
		my $comm = "perl $scripts_dir/gbk2fna.pl $num.gbk ";
		system("echo '$comm' >> $log_file");
		system($comm) ; #create $num.fna file
		$process_fail = "Fna file has not been generated! Job failed!\n";
		$process = "Fna file has been generated!\n";
		check_success_fail_exit($num, "$num.fna", $process, $process_fail, "No nucleotide sequence was detected! Please check your GenBank or FASTA sequence file!");
	}else{
		system("echo '$num.fna exist!' >> $log_file");
	}
	my $fna_end_time = time - $fna_start_time;
	system("echo 'Generating fna file took $fna_end_time sec' >> $log_file");
	write_process_file($process_file, "Generating ptt file...\n");
	my $ptt_start_time = time;

	if (!(-s "$num.ptt")){
		print "Generating ptt file from gbk ...\n";
		my $comm = "";
		if (-e "$jobs_dir/$num/$num\_master_record.gbk" && $flag eq '-g') {
			$comm = "perl $scripts_dir/gbk2ptt_contigs.pl $num.gbk $num\_contig_positions.txt > $num.ptt";
		}
		else {
			$comm = "perl $scripts_dir/gbk2ptt.pl $num.gbk > $num.ptt";
		}
		system("echo '$comm' >> $log_file");
		system($comm);
		$process_fail = "Ptt file has not been generated! Job failed!\n";
		$process = "Ptt file has been generated!\n";
		check_success_fail_exit($num, "$num.ptt", $process, $process_fail, "No .ptt file was detected! Please check your GenBank or FASTA sequence file!");
		$comm = "perl $scripts_dir/clean_empty_PID_lines.pl $num.ptt  $num.fna ";
	}
	else{
		system("echo '$num.ptt exist!' >> $log_file");
	}

	my $ptt_end_time = time - $ptt_start_time;
	system("echo 'Generating ptt file took $ptt_end_time sec' >> $log_file");

	write_process_file($process_file, "Generating faa file...\n");
	my $faa_start_time = time;
	if (!(-s "$num.faa")){
		print "Generating faa file from gbk ...\n";
		my $comm = "";
		if (-e "$jobs_dir/$num/$num\_master_record.gbk" && $flag eq '-g') {
			$comm = "perl $scripts_dir/gbk2faa_contigs.pl $num.gbk $num.fna $num\_contig_positions.txt";
		}
		else {
			$comm = "perl $scripts_dir/gbk2faa.pl $num.gbk $num.fna";
		}
		system("echo '$comm' >> $log_file");
		system("$comm >> $log_file 2>&1 ") ; #create $num.faa file
		$process_fail = "Faa file has not been generated! Job failed!\n";
		$process = "Faa file has been generated!\n";
		check_success_fail_exit($num, "$num.faa", $process, $process_fail, "No coding sequence (CDS) was detected! Please check your GenBank or FASTA sequence file!");
	}else{
		system("echo '$num.faa exist!' >> $log_file");
	}
	my $faa_end_time = time - $faa_start_time;
	system("echo 'Generating faa file took $faa_end_time sec' >> $log_file");
}

open(IN, "$num.fna") or die "Cannot open $num.fna: $!\n";
my $seq='';
my @atcg = ('A', 'C', 'T', 'G');
my %count;
while (<IN>){
	chomp($_);
	if ($_=~/^>/){
		next;
	}else{
		$seq .= $_;
		$count{$1}++ while $_=~/([@atcg])/g;
	}
}
close IN;
my $fna_len = length($seq);
my $A_count = $count{'A'};
my $T_count = $count{'T'};
my $C_count = $count{'C'};
my $G_count = $count{'G'};

system("echo 'seq length = $fna_len' >> $log_file");
system("echo 'A length = $A_count' >> $log_file");
system("echo 'T length = $T_count' >> $log_file");
system("echo 'C length = $C_count' >> $log_file");
system("echo 'G length = $G_count' >> $log_file");

my $phage_finder_start_time = time;
$time = $phage_finder_start_time - $start_time;
system("echo 'Elapsed before tRNA scanning = $time sec' >> $log_file");
system("echo '\nXXXXX running phage finder: phage_finder.sh  $num XXXXX' >> $log_file");
write_process_file($process_file, "Running tRNAscan-SE...\nRunning aragorn...\nBLASTing against virus database...\n");
system("pwd >> $log_file");
my $pid_to_program_name = {};
my $pid_to_timeout = {};
my $phage_finder_child_pid = '';
my $tRNA_tmRNA_child_pid = '';

print "Running phage search ...\n";
for(my $i=1; $i<=2; $i++){
	my $pid = fork();
	if (not defined $pid) {
	      system("echo Cannot fork!! >>$log_file");
	}elsif ($pid ==0){
		# i am a child
		
		setpgrp(0, $$) || do {
			open (LOG2, ">>$log_file.2") || die "Could not open file $log_file.2 to say setpgrp failed for i = $i: $!\n";
			print LOG2 "setpgrp failed for i = $i!\n";
			LOG2->flush();
			close(LOG2);
			die "Cannot do setpgrp\n";
			};
			# Set process group for child process and all its children, so they can all be
			# killed together if there is a failure. We use the current child process id ($$)
			# as the process group id.
		
		if ($i ==1){
			open (LOG2, ">>$log_file.2") || die "Could not open file $log_file.2: $!\n";
			print LOG2 cwd() . "\n";
			my $datestring = localtime();
			print LOG2 $datestring . "\n";
			LOG2->flush();
			if (not -x "$scripts_dir/phage_finder.sh") {
				system("chmod u+x $scripts_dir/phage_finder.sh"); # make script executable if needed
			}

			# Choose which job scheduler partition (queue) to use on the cluster, so that
			# different phases of the pipeline are run with different priority and job timeouts
			# are avoided. This is only appplicable to Botha10.
			my $queue = '';
			if($flag eq '-g') {# we have GBK file
				$queue = 'three.q';
					# Give lower priority to the BLAST against viral DB for GenBank input, since this is the first task run on the cluster for GenBank input.
					# Non-GenBank input that is at viral BLAST stage has already started its pipeline earlier (with gene prediction) and should be given a chance to complete its pipeline first.
			} else {
				$queue = 'two.q'; # Intermediate priority queue/partition.
			}

			my $local_gi_num = 0;
			my $line_num = 2;

			while ($local_gi_num == 0) {
				my $faa_last_n_lines = `tail -n $line_num $jobs_dir/$num/$num.faa`;
				if ($faa_last_n_lines =~ /\>gi\|(\d+)\|/) {
					$local_gi_num = $1;
					print LOG2 "Total number of proteins in $num.faa: $local_gi_num\n";
				}
				$line_num += 2;
			}

			my $cmd = "$scripts_dir/phage_finder.sh $num $cluster_head_virus_database $cluster_child_virus_database $local_gi_num $log_file";
			print LOG2 $cmd	. "\n";
			LOG2->flush();
			close(LOG2);
			
			my $ret = system("$cmd");
			if ($ret != 0) {
				if ($ret == -1) {
					open (LOG2, ">>$log_file.2") || die "Could not open file $log_file.2 to say that phage_finder.sh failed to run: $!\n";
					print LOG2 "phage_finder.sh failed to run\n";
					LOG2->flush();
					close(LOG2);
					exit(-1); # child process fails and exits
				} else {
					my $exitcode = $ret >> 8;
					open (LOG2, ">>$log_file.2") || die "Could not open file $log_file.2 to say that phage_finder.sh failed with exit status $exitcode: $!\n";
					print LOG2 "phage_finder.sh failed with exit status $exitcode\n";
					LOG2->flush();
					close(LOG2);
					exit(-1); # child process fails and exits
				}
			}

			exit;
		}
		if ($i==2){
			if (-e 'tRNAscan.out') {
				system("echo tRNAscan.out exists >> $log_file");
			}
			else {
				tRNA_tmRNA($num, $log_file);
			}
			system("echo 'tRNA_tmRNA done' >>$log_file");
			exit(0);
		}
		exit(0);
	}else{
		# I am the parent
		push @children, $pid;
		if ($i == 1) {
			$phage_finder_child_pid = $pid;
			$pid_to_program_name->{$pid} = 'phage_finder.sh';
			$pid_to_timeout->{$pid} = $phage_finder_tolerate_time;
		} else { # $i == 2
			$tRNA_tmRNA_child_pid = $pid;
			$pid_to_program_name->{$pid} = 'tRNA_tmRNA child process';
			$pid_to_timeout->{$pid} = $tRNAscan_tolerate_time;
		}
	}
}

# Monitor the two spawned child processes. If one of them fails or times out, kill the
# process groups associated with both children and exit.
my $children_done = {};
my $children_done_count = 0;
my $seconds_count = 0;
while(1) {
	if ($children_done_count >= 2) {
		last; # both children finished successfully
	}
	
	my $phage_finder_abort = 0;
	my $tRNAscan_abort = 0;
	my $ret = POSIX::waitpid( -1, POSIX::WNOHANG );
		# Waits for a child process to change state. See http://perldoc.perl.org/POSIX.html
		# Should behave as described here:
		# http://stackoverflow.com/questions/1980656/why-would-waitpid-in-perl-return-wrong-exit-code
	
	if ($ret > 0) { # child process id
		# The child process has exited.
		my $exitcode = $? >> 8;
		
		if ($exitcode == 0) {
			# The child process ended successfully.
			$children_done->{$ret} = 0;
			$children_done_count++;
		} else {
			# The child process failed.
			my $program_name = $pid_to_program_name->{$ret};
			system("echo '$program_name failed with exit status $exitcode. Program exit!' >>$log_file.3");
			if ($program_name eq 'tRNA_tmRNA'){
				$tRNAscan_abort = 1;
			}else{
				$phage_finder_abort = 1;
			}

		}
	} elsif ($ret == 0) {
		# The child process(es) is/are still running. Check timeout.
		if ($seconds_count > $tRNAscan_tolerate_time) {
			if (!(exists $children_done->{$tRNA_tmRNA_child_pid})) {
				my $program_name = $pid_to_program_name->{$tRNA_tmRNA_child_pid};
				system("echo '$program_name timed out! Program exit!' >>$log_file.3");
				$tRNAscan_abort = 1;
			} elsif ($seconds_count > $phage_finder_tolerate_time) {
				if (!(exists $children_done->{$phage_finder_child_pid})) {
					my $program_name = $pid_to_program_name->{$phage_finder_child_pid};
					system("echo '$program_name timed out! Program exit!' >>$log_file.3");
					$phage_finder_abort = 1;
				}
			}
		}
	} elsif ($ret == -1) {
		# Child processes do not exist anymore.
		if ($children_done_count == 0) {
			system("echo 'child processes unexpectedly vanished! Program exit!' >>$log_file.3");
			$phage_finder_abort = 1;
			$tRNAscan_abort = 1;
		} else {
			my $missing_program = '';
			if (!(exists $children_done->{$tRNA_tmRNA_child_pid})) {
				$missing_program = $pid_to_program_name->{$tRNA_tmRNA_child_pid};
			} elsif (!(exists $children_done->{$phage_finder_child_pid})) {
				$missing_program = $pid_to_program_name->{$phage_finder_child_pid};
			} else {
				$missing_program = 'unknown child process(es)'; # ??
			}
			
			system("echo '$missing_program unexpectedly vanished! Program exit!' >>$log_file.3");
			if ($missing_program == $pid_to_program_name->{$phage_finder_child_pid}){
				$phage_finder_abort = 1;
			}else{
				$tRNAscan_abort = 1;
			}
		}
	} else { # $ret < -1
		# Unexpected problem.
		system("echo 'Unexpected return value from waitpid!' >>$log_file.3");
		$phage_finder_abort = 1;
		$tRNAscan_abort = 1;
	}
	
	if ($phage_finder_abort != 0) {
		kill -9, $children[0];
		# sometimes still have to manually kill the tRNAscan process. We cannot let it abort.
		# just let it keep going.
		exit(-1);
	}
	if ($tRNAscan_abort != 0) {
		kill -9, $children[1];
		# sometimes still have to manually kill the tRNAscan process. We cannot let it abort.
		# just let it keep going.
		last;
	}
	sleep(3);
	$seconds_count += 3;
}
print "Fork is done ...\n";
my $done_phage_finder_time = time;
$time = $done_phage_finder_time - $start_time;
system("echo 'phage_finder.sh and tRNA_tmRNA() done at $time sec' >> $log_file");
$time = $done_phage_finder_time - $phage_finder_start_time;
system("echo 'phage_finder.sh and tRNA_tmRNA() took $time sec' >> $log_file");

if (-e "ncbi.not_done"){
	$process_fail = `date`."Time is over $phage_finder_tolerate_time min. There is no BLAST output ncbi.out of job $num from cluster. Please inform the administrator of the server.\nProgram terminated!\n";
        $process = "";
	system("echo '$process_fail' >> $log_file");
	my %mail = (To => $email_receiver,
		    From => $email_sender,
		    Message => $process_fail
		   );
	sendmail(%mail) or system("echo '".$Mail::Sendmail::error. "' >> $log_file");
	put_back_case_clean_process_exit($num,  $process_fail, $running_case_file); 
}

system("cat $log_file.2 >> $log_file; rm -rf $log_file.2");

if (!(-e "tRNAscan.out")){
	system("echo No tRNAscan.out >> $log_file");
}
$process_fail = "There is no output from tRNAscan-SE!\n";
$process = "Running tRNAscan-SE is done!\n";
if (-e "tRNAscan.not_done"){
	$process = "Running tRNAscan-SE is not done!\n";
}
check_write_process_file("tRNAscan.out", $process_file, $process, $process_fail);

if (!(-e "tmRNA_aragorn.out")){
	system("echo No tmRNA_aragorn.out >> $log_file");
}
$process_fail = "There is no output from aragorn!\n";
$process = "Running aragorn is done!\n";
check_write_process_file("tmRNA_aragorn.out", $process_file, $process, $process_fail);

system("echo 'XXXXX finish running phage finder  XXXXX\n' >> $log_file");

my $phage_finder_time = time;
$time = $phage_finder_time - $start_time;
system("echo 'phage_finder and checks done at $time sec' >> $log_file");

if (!(-s "ncbi.out")){
	$process_fail = "There is no BLAST hit found in the virus database!\n";
	$process = "BLASTing against virus databse is done!\n";
	check_write_process_file("ncbi.out", $process_file, $process, $process_fail);
}

my $NC='N/A';
my $gi='N/A';
if (-e "$num.gbk"){
	my $data =`cat $num.gbk`;
	if($data=~/\nVERSION\s+(\S+)\s+GI:(\d+)\n/s){
		$gi = $2;
		$NC=$1;
	}
}else{
	$NC="NC_000000";
}
if ($NC eq 'N/A' or $NC eq ''){
	$NC="NC_000000";
}
system("echo 'NNNNNN NC=$NC' >> $log_file");
if (!(-d "$jobs_dir/$num/$NC\_dir")){
	system("mkdir -p $jobs_dir/$num/$NC\_dir");
}
chdir "$jobs_dir/$num/$NC\_dir";
##### Rah's part###########
my $start_blast_time = time;
$time = $start_blast_time - $start_time;
print "Scanning for phage regions ...\n";
system("echo 'scan.pl started at $time sec' >> $log_file");
write_process_file($process_file, "Looking for phage-like regions...\n");
my $cm = "perl $scripts_dir/scan.pl -n $jobs_dir/$num/$num.fna  -a $jobs_dir/$num/$num.faa  -t  $jobs_dir/$num/RNA_output.out -m $jobs_dir/$num/tmRNA_aragorn.out  -b $jobs_dir/$num/ncbi.out  -p $jobs_dir/$num/$num.ptt  -use 5";
$cm .= " -g $jobs_dir/$num/$num.gbk" if (-e "$jobs_dir/$num/$num.gbk");
$cm .= " -c $jobs_dir/$num/$num\_contig_positions.txt" if (-e "$jobs_dir/$num/$num\_contig_positions.txt");
system("echo '$cm'>> $log_file");
system("$cm >$NC\_phmedio.txt  2>>$log_file")==0 or system("echo $! >> $log_file");

$process_fail = "There were no phage-like regions found!\n";
$process = "Looking for regions is done!\n";
check_success_fail_exit($num, "$NC\_phmedio.txt" , $process, $process_fail, "No prophage region detected!");	

system("echo 'perl  $scripts_dir/non_hit_region_pro_to_faa.pl $jobs_dir/$num/$num.faa  $NC\_phmedio.txt $jobs_dir/$num/$num.faa.non_hit_pro_region $anno_flag' >> $log_file");
system("perl  $scripts_dir/non_hit_region_pro_to_faa.pl $jobs_dir/$num/$num.faa  $NC\_phmedio.txt $jobs_dir/$num/$num.faa.non_hit_pro_region $anno_flag 2>&1 |cat >> $log_file")==0 or system("echo $! >> $log_file");

my $done_blast_time = time;
$time = $done_blast_time - $start_blast_time;
system("echo 'scan.pl took $time sec' >> $log_file");
$time = $done_blast_time - $start_time;
system("echo 'scan.pl done at $time sec' >> $log_file");

# if the input is raw fasta sequence only, we have to get back annotations for scan/phage finder's output result.

if ($flag ne '-g' && !-e "$jobs_dir/$num/ncbi.out.non_hit_pro_region"){
	print "Searching against non-phage sequences ...\n";
	# we need to get the blast result for non hit region proteins first

	write_process_file($process_file, "BLASTing non-phage-like proteins of hit regions against bacterial database...\n");
	system("echo Parallel BLASTing on bacterial database for non-hit-region-proteins... >> $log_file");

	my $start_non_hit_time = time;
	$time = $start_non_hit_time - $start_time;
	system("echo 'Start parallel BLASTing non-hit regions at $time sec' >> $log_file");

	if (-z "$jobs_dir/$num/$num.faa.non_hit_pro_region") {
		# There are no non-hit genes (i.e. genes that did not have hits in virus DB). So skip
		# BLAST against Bacterial DB.'
		my $start_call_remote_dmnd_time = time;
		system('touch $jobs_dir/$num/ncbi.out.non_hit_pro_region');

		my $end_call_remote_dmnd_time = time;
		$time = $end_call_remote_dmnd_time - $start_call_remote_dmnd_time;
		system("echo 'No non-hit sequences to BLAST. Skip call_remote_dmnd.sh and touch ncbi.out.non_hit_pro_region took $time sec' >> $log_file");
	} else {
		my $blast_b_dir="$jobs_dir/$num/tmp/blast_b";
		if (not -x "$scripts_dir/call_remote_dmnd.sh") {
			system("chmod u+x $scripts_dir/call_remote_dmnd.sh"); # make script executable if needed
		}

		my $local_gi_num = 0;
		my $line_num = 2;

		while ($local_gi_num == 0) {
			my $faa_last_n_lines = `tail -n $line_num $jobs_dir/$num/$num.faa`;
			if ($faa_last_n_lines =~ /\>gi\|(\d+)\|/) {
				$local_gi_num = $1;
			}
			$line_num += 2;
		}

		my $start_call_remote_dmnd_time = time;
		my $cm = "$scripts_dir/call_remote_dmnd.sh  $blast_b_dir  $jobs_dir/$num/$num.faa.non_hit_pro_region  $cluster_head_bac_database $cluster_child_bac_database $jobs_dir/$num/ncbi.out.non_hit_pro_region $log_file";
		open (LOG, ">>$log_file");
		print LOG "$cm\n";
		LOG->flush();
		close(LOG);
		my $ret = system("$cm");
		if ($ret != 0) {
			if ($ret == -1) {
				my $msg = "call_remote_dmnd.sh failed to run";
				open (LOG, ">>$log_file");
				print LOG "$msg\n";
				LOG->flush();
				close(LOG);
				error_exit($num, 'Error running BLAST')
			} else {
				my $exitcode = $ret >> 8;
				my $msg = "call_remote_dmnd.sh failed with exit status $exitcode";
				open (LOG, ">>$log_file");
				print LOG "$msg\n";
				LOG->flush();
				close(LOG);
				error_exit($num, 'Error running BLAST')
			}
		}
		my $end_call_remote_dmnd_time = time;
		$time = $end_call_remote_dmnd_time - $start_call_remote_dmnd_time;
		system("echo 'call_remote_dmnd.sh took $time sec' >> $log_file");
	}
	$process_fail = "There was a problem running BLAST against the bacterial sequence database!\n";
	$process = "BLASTing non-phage-like proteins against bacterial database is done!\n";
	check_write_process_file("$jobs_dir/$num/ncbi.out.non_hit_pro_region", $process_file, $process, $process_fail);

	my $done_non_hit_time = time;
	$time = $done_non_hit_time - $done_blast_time;
	system("echo 'Parallel BLASTing non-hit regions took $time sec' >> $log_file");
	$time = $done_non_hit_time - $start_time;
	system("echo 'Parallel BLASTing non-hit regions done at $time sec' >> $log_file");

}
print "Annotating proteins in regions ...\n";
my $annotation_start_time = time;
write_process_file($process_file, "Annotating proteins in regions found...\n");
$cm = "perl $scripts_dir/annotation.pl $NC $num  $local_virus_header_database  $local_bac_header_database $jobs_dir/$num/ncbi.out.non_hit_pro_region $NC\_phmedio.txt $jobs_dir/$num/RNA_output.out $jobs_dir/$num/$num.ptt $flag $anno_flag";
system("echo '$cm' >> $log_file");
system("$cm  2>&1 |cat >> $log_file");	
$process = "Annotating proteins in regions found  is done!\n";
write_process_file($process_file, $process);
my $done_annotation_time = time;
$time = $done_annotation_time - $annotation_start_time;
system("echo 'annotation.pl plus waiting took $time sec' >> $log_file");
$time = $done_annotation_time - $start_time;
system("echo 'annotation.pl done at $time sec' >> $log_file");

my $extract_protein_start_time = time;
$cm="perl $scripts_dir/extract_protein.pl $num $NC\_phmedio.txt $num.ptt extract_result.txt $anno_flag";
system("$cm"); #create file 'extract_result.txt' and "NC_XXXX.txt";
system("echo '$cm' >>$log_file");
print_msg("extract_result.txt", $log_file);
my $extract_protein_end_time = time;
$time = $extract_protein_end_time - $extract_protein_start_time;
system("echo 'extract_protein.pl took $time sec' >> $log_file");

print "Get true regions ...\n";
#now use filter to get result files.
my $get_true_region_start_time = time;
write_process_file($process_file, "Generating summary file...\n");
$cm = "perl $scripts_dir/get_true_region.pl $NC\_phmedio.txt  extract_result.txt  true_defective_prophage.txt";
system("echo '$cm' >> $log_file");
system($cm)==0 or system("echo $! >> $log_file"); # create true_defective_prophage.txt
system("cp true_defective_prophage.txt  $jobs_dir/$num/.");
system("cp true_defective_prophage.txt  $jobs_dir/$num/summary.txt");
$process_fail = "There is no summary file generated!\n";
$process = "Summmary file is generated!\n";
check_success_fail_exit($num, "true_defective_prophage.txt" , $process, $process_fail, "No summary file was generated!");	
my $get_true_region_end_time = time;
$time = $get_true_region_end_time - $get_true_region_start_time;
system("echo 'get_true_region.pl took $time sec' >> $log_file");

# get image
### make png format image
if (-s 'extract_result.txt'){
	my $png_start_time = time;
	system("cp extract_result.txt $jobs_dir/$num/detail.txt");
	write_process_file($process_file, "Generating image file...\n");

	# This command creates json_input and json_input_regions file.
	$cm="perl $scripts_dir/make_json.pl extract_result.txt  true_defective_prophage.txt  $num $flag";
	
	system("echo '$cm' >> $log_file");
	system("$cm  >> $log_file"); # create file json_input and json_input_regions.
	print_msg("image.png", $log_file);
	system("cp json_input json_input_regions $jobs_dir/$num/.");
	
	my $png_end_time = time;
	$time = $png_end_time - $png_start_time;
	system("echo 'make_json.pl took $time sec' >> $log_file");
}

#mark finished 
if (!(-e "$jobs_dir/$num/fail.txt") && (-e "$jobs_dir/$num/true_defective_prophage.txt")){
	system("touch $jobs_dir/$num/success.txt");
	my $date = `date`;
	if (-e "$jobs_dir/$num/tRNAscan.not_done"){
		system("echo '$num  $date  fail  tRNAscan not working' >> $jobs_dir/case_record.log");
	}else{
		system("echo '$num  $date  success' >> $jobs_dir/case_record.log");
	}
	
};
#cleanup
cleanup($num, $flag);
system("echo 'Program exit!' >> $log_file");
# TODO - UNCOMMENT to display timing messages at the end of log file
generate_timing_message($num); #generate_timing_message($log_file); 
print "Program exit!\n";
exit;

sub cleanup{
	print "Cleaning up ...\n";
	my $num=shift;
	my $flag = shift;
	make_done_file($num);
	make_region_DNA($num); # create region DNA file "region_DNA.txt"
	my $last_time = time;
	$time = $last_time - $start_time;
	system("echo  'Program finished, taking $time seconds!' >> $log_file");
	write_process_file($process_file, "Program finished!\n");

	system("echo 'rm -rf $running_case_file' >>$log_file");
	unlink  $running_case_file;

	# Delete temp files before copying it to the backend cluster.
	my $cur_dir = getcwd;
	chdir "$jobs_dir/$num";
 	$cmd = "rm -rf *_dir  extract_RNA_result*  ncbi* tmRNA* tRNAscan* true_defective_prophage.txt *faa *non_hit_pro_region *predict *process *ptt *gbk *txt_* *.txt.old image.png *tmp *fai *gff *out";
	system("echo '$cmd' >> $log_file");
	system($cmd);
	chdir $cur_dir;
}

# Generate timing messages on the log file, and also json file containing time messages.
# All time messages are null in case of job fail.
sub generate_timing_message{
	$num = shift;
	$log = "$jobs_dir/$num/$num.log";
	my @arr = ();

	open('log') or die("Could not open log file.");
	foreach $line (<log>) { #<log_file>
		chomp($line);

		if (index($line, " sec") != -1){
			push (@arr, $line);
		}
		if (index($line, "seq length") != -1) {
			push (@arr, $line);
		}
	}

	close $log;

	my ($gbk, $gene, $len, $fna, $faa, $ptt, $phage, $trna, $scan, $bact, $anno, $json, $total) = ('','','','','','','','','','','','','');
	my $success = 1;
	$success = 0 if -e "$jobs_dir/$num/fail.txt";
	system("echo '\n\n\nTIMING MESSAGES\n' >> $log_file");
	foreach my $a (@arr){
		system("echo '$a' >> $log_file");

		$gbk 	= $1 if $a =~ /Genbank.*\s(\d+) sec/;
		$gene 	= $1 if $a =~ /(?:prodigal|FragGeneScan).*\s(\d+) sec/;
		$len	= $1 if $a =~ /seq length = (\d+)/;
		$fna 	= $1 if $a =~ /Generating fna.*\s(\d+) sec/;
		$faa 	= $1 if $a =~ /Generating faa.*\s(\d+) sec/;
		$ptt 	= $1 if $a =~ /Generating ptt.*\s(\d+) sec/;
		$phage 	= $1 if $a =~ /Phage.*\s(\d+) sec/;
		$trna 	= $1 if $a =~ /tRNAscan-SE.*\s(\d+) sec/;
		$scan 	= $1 if $a =~ /scan.*took\s(\d+) sec/;
		$bact 	= $1 if $a =~ /non-hit.*took\s(\d+) sec/;
		$anno 	= $1 if $a =~ /annotation.pl plus.*\s(\d+) sec/;
		$json 	= $1 if $a =~ /json.* took\s(\d+) sec/;
		$total 	= $1 if $a =~ /Program.*\s(\d+) sec/;
	}

	# Size, length, ACTG content,
	my $timing = {
		"query" => "\"$num\"",
		"flag" => "\"$flag\"",
		"success" => "$success",
		"seq_length" => "$len",
		"genbank_retrieval" => "$gbk",
		"gene_prediction" => "$gene",
		"fna_generation" => "$fna",
		"faa_generation" => "$faa",
		"ptt_generation" => "$ptt",
		"phage_alignment" => "$phage",
		"tRNA_detection" => "$trna",
		"phage_scan" => "$scan",
		"bact_alignment" => "$bact",
		"bact_annotation" => "$anno",
		"make_json" => "$json",
		"total" => "$total"
	};

	open(FH, ">", "$jobs_dir/$num/timing_messages");
	print FH "[\n";
	print FH "\t{\n";
	foreach my $i ("query", "flag", "success", "seq_length", "genbank_retrieval", "gene_prediction", 
				   "fna_generation", "faa_generation", "ptt_generation", "phage_alignment", "tRNA_detection", 
				   "phage_scan", "bact_alignment", "bact_annotation", "make_json", "total") {
		
		my $elem = "null";
		$elem = "$timing->{$i}" if $timing->{$i} ne "";

		print FH "\t\t\"$i\":$elem";
		$i ne "total" ? (print FH ",\n") : (print FH "\n");
	}
	print FH "\t}\n";
	print FH "]";
	close FH;
}

sub make_browse{
	my $num =shift;
	if ($num !~ /^1/ ||  length($num) !=10){
    	unlink "$jobs_dir/make_browse_list";
	    system("echo 'remove $jobs_dir/make_browse_list' >> $log_file") if (!-e "$jobs_dir/make_browse_list");
    	system("echo 'perl $scripts_dir/make_browse.pl' >> $log_file");
	    system("perl $scripts_dir/make_browse.pl >> $log_file")==0 or system("echo 'Error:$!' >> $log_file"); # make browse.html
	}
}	

sub make_done_file{
	my $num = shift;
	if (-e "$jobs_dir/$num/$num.fna"){
 	   	my $content=`cat $jobs_dir/$num/$num.fna`;
    	if ($content=~/>(.*?)\n/s){
        	my $desc=$1;
	        if ($desc=~/gi\|(\d+)\|ref\|(.*?)\|/){
    	        $NC= $2;
        	    $gi = $1;
	        }
    	    $desc =~s/DEFINITION//si;
        	$desc =~s/gi\|\d+\|\s*//si;
	        $desc =~s/ref\|(.*?)\|\s*//si;
    	    system("echo '$desc' >  $jobs_dir/$num/$num.done");
        	system("echo 'ACCESSION: $NC' >> $jobs_dir/$num/$num.done");
	        system("echo 'GI: $gi' >> $jobs_dir/$num/$num.done");
    	}
	}
	if (-e "$jobs_dir/$num/$num.done"){
		system("echo '$jobs_dir/$num/$num.done generated' >>$log_file");
	}else{
		system("echo '$jobs_dir/$num/$num.done Not generted' >> $log_file");
	}
}

# Rewrite fna file to limit sequence lines to 70 bases. If the sequence is not in multiple
# lines, tRNAscan will get trouble. Will work with multi-FASTA file as well as single
# FASTA sequence.
sub fix_fna_lines {
	my $filename = shift;
	open(IN, "$filename");
	open(OUT, ">$filename.tmp");
	my $head = ''; my $seq_tmp = '';
	while(<IN>){
		if ($_=~/>/){
			if ($seq_tmp ne '') {
				my @tmp = $seq_tmp =~/(\w{0,60})/g; 
				print OUT $head;
				print OUT join("\n", @tmp);
				$seq_tmp = '';
			}
			
			$head = $_;
		}else{
			if ($_ =~ /([A-Z]+)/i) {
				$seq_tmp .= $1;
			}
		}
	}
	close IN;
	if ($seq_tmp ne '') {
		my @tmp = $seq_tmp =~/(\w{0,60})/g; 
                $head =~s/>/-/g; $head=~s/^-/>/;
		print OUT $head;
		print OUT join("\n", @tmp);
		$seq_tmp = '';
	}
	close OUT;
	system("mv $filename.tmp $filename");
}

sub get_gbk_file{
    system("echo 'in get gbk file on server' >> $log_file");
    my ($num,  $log_file, $jobs_dir)= @_;
	system("perl $scripts_dir/get_gbk.pl $num  $jobs_dir/$num 2>&1|cat >> $log_file.2"); # create $num.gbk file
	system("cat $log_file.2 >> $log_file; rm -rf $log_file.2");
    print_msg("$num.gbk", $log_file);
}

sub print_msg{
	my ($file, $log_file)= @_;
	if (-s $file ){
		system("echo  $file is created ! >> $log_file");
	}else{
		system("echo  $file is not created ! >> $log_file");
	}
}


# Arguments:
#  $num: Job ID.
#  $msg: Public error message to display to user.
sub error_exit {
    my($num, $msg)=@_;
    system("echo '$msg' >> $jobs_dir/$num/fail.txt");
    system("touch $jobs_dir/$num/summary.txt");
    system("touch $jobs_dir/$num/detail.txt");
	generate_timing_message($num);
    my $date = `date`;
    system("echo '$num  $date fail $msg' >> $jobs_dir/case_record.log");
    if (defined $running_case_file && $running_case_file ne ''){
        system("echo 'rm -rf $running_case_file' >>$log_file");
        unlink  $running_case_file;
    }
	chdir "$jobs_dir/$num";
 	$cmd = "rm -rf *_dir  extract_RNA_result*  ncbi* tmRNA* tRNAscan* true_defective_prophage.txt *faa *non_hit_pro_region *predict *process *ptt *gbk *txt_* *.txt.old image.png *tmp *fai *gff *out";
	system("echo '$cmd' >> $log_file");
	system($cmd);
    system("echo 'Program exit!' >> $log_file");
    exit(-1);
}

sub check_success_fail_exit{
	my ($num, $file,$process, $process_fail,  $msg)=@_;
	print_msg($file, $log_file);
	check_write_process_file($file, $process_file, $process, $process_fail);
	if (!(-s $file)){
        error_exit($num, $msg);
	}
}

# output process file for tracing the process of the case. 
sub write_process_file{
	my ($process_file, $msg)=@_;
	open(OUT, ">>$process_file") or die "Cannot write $process_file";
	print OUT $msg;
	close OUT;
}

# check file's existence, and output process file
sub check_write_process_file{
	my ($file, $process_file, $success_msg, $fail_msg)=@_;
	if (-s $file) {
		write_process_file($process_file, $success_msg);
	}else{
		write_process_file($process_file, $fail_msg);	 
	}
}

sub make_region_DNA{
	my $num=shift;
	my $cur_dir = getcwd;
	chdir "$jobs_dir/$num";
	my $DNA_seq= `grep -v '>' $num.fna`;
	$DNA_seq=~s/[\s\n]//gs;
	my $sum_file_content=`cat summary.txt`;
	$sum_file_content=~s/.*---------------+\n//s;
	my @pos=();
	foreach my $line(split "\n", $sum_file_content){
		my @tmp=split " ", $line;
		push @pos, $tmp[4];
	}	
	if (@pos !=0){
		open(OUT, ">region_DNA.txt") or die "Cannot write region_DNA.txt";
		for(my $i=0; $i <=$#pos; $i++){
			my ($start, $end)= $pos[$i]=~/(\d+)-(\d+)/;
			print OUT ">".($i+1)."\t $pos[$i]\n";
			my $seq= substr($DNA_seq, $start-1, $end-$start+1);
			my @tmp=$seq=~/(\w{0,60})/gs;
			foreach my $l(@tmp){
				print OUT $l."\n";
			}
			print OUT "\n";
		}
		close OUT;
	}
	chdir $cur_dir;
}

# check the gbk file. if there is CDS and translation sections, we keep it.
# if there is CDS and no translation sections , we make translation section into it.
# if there is no CDS and no translation sections, we make fna file .

#TODO Remove this function once rails side validations complete
sub check_gbk_file{
	my $gbk_file = shift;
	my $num = shift;
	open (IN, $gbk_file);
	my $translation_flag  = 0;
	my $db_xref_flag =0;
	my $CDS_flag= 0;
	my $seq_flag =0;
	my $seq ='';
	my %hash =();
    my @keys=();
	my $desc = '';
	my $NC='';
	my $GI='';
	while (<IN>){
		chomp($_);
		if ($_=~/^VERSION\s+(\S+)\s+GI:(\d+)/){
			$GI = $2;
			$NC = $1
		}
		if ($_=~/^DEFINITION\s+(.*)/){
			$desc=$1;
		}
		if ($_=~/^\s*CDS\s+(\S+)/ ){
            push @keys, $1;
			$hash{$1}='';
			$CDS_flag = 1;
		}elsif($_=~/^\s+\/db_xref="GI:/){
			$db_xref_flag = 1;
		}elsif($_=~/^\s+\/translation="/){
			$translation_flag = 1;	
		}elsif($_=~/^ORIGIN/){
			$seq_flag = 1;
			next;
		}elsif($_=~/^\/\//){
			$seq_flag = 0;
		}		
		if ($seq_flag==1){
			$_=~s/[\d\s\n]//g;
 			$_=uc($_);
			$seq .= $_;
		}
	}
	close IN;
	if ($seq ne ''){
		$seq_flag=1;
	}
	my $DNA_seq = $seq;
	$DNA_seq =~s/[ACGTRYKMSWBDHVN]//sig;
	if ($DNA_seq ne ''){
		$DNA_seq=~s/(\w{0,60})/$1\n/gs;
		$process_fail = "Wrong DNA seq = $DNA_seq in gbk file! We accept 'ACGTRYKMSWBDHVN' only.\nProgram terminated!\n";
		$process = "";
		check_success_fail_exit($num, "NA_wrong_seq", $process, $process_fail, $process_fail);	
	}
	system("echo 'seq_flag=$seq_flag, CDS_flag=$CDS_flag, db_xref_flag=$db_xref_flag, translation_flag=$translation_flag, NC=$NC, GI=$GI, desc=$desc' >> $log_file");
	if ($seq_flag ==0){
		my $content= `cat $gbk_file`;
		$process_fail = "There is no ORIGIN part in GBK file. That is weird.\n\n<pre>$content</pre>";
	        $process = "There is DNA part in GBK file.\n";
        	check_success_fail_exit($num, "DNA_no_seq", $process, $process_fail, $process_fail);

	}	
	elsif ($seq_flag==1 && $CDS_flag ==1 && ($db_xref_flag==0 or $translation_flag ==0) ){ # there is CDS section
		system("echo 'Generate translation section for gbk file' >> $log_file");
		foreach my $k (@keys){
			$hash{$k} = get_seq(\$seq, $k);
		}
		open (IN, $gbk_file);
		open (OUT, ">$gbk_file.tmp");
		my $key = '';
		my $flag =0;
		my $gi_count=0;
		while(<IN>){
			if ($_=~/^\s*CDS\s+(\S+)/ ){
				$key = $1;
                if ($key =~/complement\((\d+)\.\.(\d+)\)/ || $key =~/(\d+)\.\.(\d+)\)/){
					if ($2<$1){
						$start= $1; $end=$2;
						$key =~s/\d+\.\.\d+/$end\.\.$start/;
					    $_=~s/CDS\s+\S+/CDS             $key/;	
					}
				}
				$flag = 1;	 
				print OUT $_;
				if ($db_xref_flag==0){ # no db_xref
                    $gi_count++;
                    print OUT "                     \/db_xref=\"GI:$gi_count\"\n";
                }
				next;
			}
			if ($_!~/^\s+\// && $key ne '' && $flag ==1){
				if ($translation_flag ==0){# no translation
					print OUT "                     \/translation=\"$hash{$key}\"\n";
				}
				$key ='';
				$flag =0;
			}
			print OUT $_;
		}
		close IN;
		close OUT;
		system("cp -f $gbk_file.tmp $gbk_file");
		$translation_flag = 1;
	}
	elsif ($seq_flag==1 && $CDS_flag ==0 && $translation_flag ==0){# no translation and no CDS
		system("echo 'Make fna file from gbk file' >> $log_file");
		$seq = uc($seq);
		my @arr= $seq =~/\w{0,60}/g;
		open (OUT, ">$num.fna");
		chomp($desc);
		print OUT ">gi|$GI|ref|$NC| $desc\n";
		foreach my $l (@arr){
			print OUT $l."\n";
		}
		close OUT;
	}else{
		system("echo 'Keep gbk file intact' >> $log_file");
	}
	return $translation_flag;
}

# get translation sequence--protein_seq for each CDS 
sub  get_seq{
	my ($seq, $locations )=@_;
	my $seq3 = '';
	my $start_num='';
	my $end_num = '';
	my $len='';
	my @arr =();
	if ($locations=~/complement\(\d+\.\.\d+\)/){
		@arr= $locations=~/(complement\(\d+\.\.\d+\))/g;
	}
	elsif ($locations=~/\d+\.\.\d+/){
		@arr= $locations=~/(\d+\.\.\d+)/g;
	}
	
	foreach my $l (@arr){
		my $seq2 = '';
		if ($l =~/complement\((\d+)\.\.(\d+)\)/){
			$start_num = $1;
			$end_num = $2;	
            if ($start_num > $end_num){
				my $tmp= $end_num;
                $end_num=$start_num;
                $start_num = $tmp;
            }
			$len = $end_num-$start_num+1;
			$seq2 = substr($$seq, $start_num-1, $len);
		
			$seq2 =~ tr/[A,T,C,G,a,t,c,g]/[T,A,G,C,t,a,g,c]/;
			$seq2 = scalar reverse($seq2);
		
		}elsif($l =~/(\d+)\.\.(\d+)/){
			$start_num = $1;
			$end_num = $2;		
            if ($start_num > $end_num){  
                my $tmp= $end_num;
                $end_num=$start_num;
                $start_num = $tmp;
            }
			$len = $end_num-$start_num+1;
			$seq2 = substr($$seq, $start_num-1, $len);
		}
		$seq3 .= $seq2;
	}
	$seq3 = change_to_aa ($seq3);
	return $seq3;
}

# change nucleotide acid to amino acid.
sub change_to_aa{
	my $seq = shift;
	my @arr = $seq=~/\w{0,3}/g;
	foreach my $i (0..$#arr){
		if ($arr[$i]=~/\w\w\w/){
			$arr[$i] =~s/TTT/F/i;$arr[$i] =~s/TTC/F/i;$arr[$i] =~s/TTA/L/i;$arr[$i] =~s/TTG/L/i;$arr[$i] =~s/CTT/L/i;$arr[$i] =~s/CTC/L/i;
			$arr[$i] =~s/CTA/L/i;$arr[$i] =~s/CTG/L/i;$arr[$i] =~s/ATT/I/i;$arr[$i] =~s/ATC/I/i;$arr[$i] =~s/ATA/I/i;$arr[$i] =~s/ATG/M/i;
			$arr[$i] =~s/GTT/V/i;$arr[$i] =~s/GTC/V/i;$arr[$i] =~s/GTA/V/i;$arr[$i] =~s/GTG/V/i;$arr[$i] =~s/TCT/S/i;$arr[$i] =~s/TCC/S/i;
			$arr[$i] =~s/TCA/S/i;$arr[$i] =~s/TCG/S/i;$arr[$i] =~s/CCT/P/i;$arr[$i] =~s/CCC/P/i;$arr[$i] =~s/CCA/P/i;$arr[$i] =~s/CCG/P/i;
			$arr[$i] =~s/ACT/T/i;$arr[$i] =~s/ACC/T/i;$arr[$i] =~s/ACA/T/i;$arr[$i] =~s/ACG/T/i;$arr[$i] =~s/GCT/A/i;$arr[$i] =~s/GCC/A/i;
			$arr[$i] =~s/GCA/A/i;$arr[$i] =~s/GCG/A/i;$arr[$i] =~s/TAT/Y/i;$arr[$i] =~s/TAC/Y/i;$arr[$i] =~s/TAA//i;$arr[$i] =~s/TAG//i;
			$arr[$i] =~s/CAT/H/i;$arr[$i] =~s/CAC/H/i;$arr[$i] =~s/CAA/Q/i;$arr[$i] =~s/CAG/Q/i;$arr[$i] =~s/AAT/N/i;$arr[$i] =~s/AAC/N/i;
			$arr[$i] =~s/AAA/K/i;$arr[$i] =~s/AAG/K/i;$arr[$i] =~s/GAT/D/i;$arr[$i] =~s/GAC/D/i;$arr[$i] =~s/GAA/E/i;$arr[$i] =~s/GAG/E/i;
			$arr[$i] =~s/TGT/C/i;$arr[$i] =~s/TGC/C/i;$arr[$i] =~s/TGA//i;$arr[$i] =~s/TGG/W/i;$arr[$i] =~s/CGT/R/i;$arr[$i] =~s/CGC/R/i;
			$arr[$i] =~s/CGA/R/i;$arr[$i] =~s/CGG/R/i;$arr[$i] =~s/AGT/S/i;$arr[$i] =~s/AGC/S/i;$arr[$i] =~s/AGA/R/i;$arr[$i] =~s/AGG/R/i;
			$arr[$i] =~s/GGT/G/i;$arr[$i] =~s/GGC/G/i;$arr[$i] =~s/GGA/G/i;$arr[$i] =~s/GGG/G/i;
		}else{
			$arr[$i]='';
		}
	}
	return join('',@arr); 

}

sub put_back_case_clean_process_exit{
	my ($num,  $msg, $running_file)=@_;
	my $queue_data= `cat $queue_file`;
	open(OUTQ, ">$queue_file");
    print OUTQ `cat $running_file`;
    print OUTQ $queue_data;
    close OUTQ;
    unlink $running_file;
	if (-s $running_file){
		system("echo 'Cannot remove $running_file' >> $jobs_dir/case_record.log");
		print "Cannot remove $running_file\n";
	}else{
		system("echo 'Remove $running_file' >> $jobs_dir/case_record.log");
  		print "Remove $running_file\n";
	}
	$queue_data= `cat $queue_file`;
	if ($queue_data =~/$num/s){
		system("echo '$num is back to $queue_file' >> $jobs_dir/case_record.log");
		print "$num is back to $queue_file\n";
	}else{
		system("echo '$num is NOT back to $queue_file' >> $jobs_dir/case_record.log");
		print "$num is NOT back to $queue_file\n";
	}
	system("echo '$msg' >> $jobs_dir/case_record.log");
	print "$msg\n";
	chdir "$jobs_dir/$num";
	system("rm  -rf *done *ptt *faa* *ncbi.out*  tRNA*  tmRNA* *process *_dir");
    my $process = `ps x`;
    foreach my $ps (split("\n", $process)){
	    if ($ps =~/^\s*(\d+) .*?$num/){
			system("echo 'kill -9 $1 for $num' >> $jobs_dir/$num/$num.log.3");
			system("echo 'kill -9 $1' >>$jobs_dir/case_record.log");
        	system("kill -9 $1");
		        
	    }else{
			if ($ps=~/$num/){
				system("echo 'No $ps captured' >> $jobs_dir/case_record.log");
			}
		}
    }
	system("echo 'kill -9 $CURRENT_PID for $num 's phage.pl' >> $jobs_dir/$num/$num.log.3");
    system("echo 'kill -9 $CURRENT_PID of phage.pl' >>$jobs_dir/case_record.log");
    system("kill -9 $CURRENT_PID");
    exit;
	
}

sub tRNA_tmRNA{
    my ($num, $log_file)=@_;
		open (LOG, ">>$log_file");
		print LOG "tRNAscan-SE -B -o tRNAscan.out $num.fna\n";
		print LOG "find tRNA sequences ...\n";
    
    my $trnascan_start = time;
	my $pid = open(my $fh, '-|', "tRNAscan-SE -B -o tRNAscan.out $num.fna 2>&1") or die $!;
	while (my $line = <$fh>) {
		print LOG $line;
		if ($line =~ /WARNING: tRNAscan.out exists already/) {
			system("kill -9 $pid"); # Kill tRNAscan-SE. If we do not, since it is interactive it will fill up the log file until the hard disk is full.
			print LOG "tRNAscan-SE found already existing tRNAscan.out file! Kill tRNAscan-SE and abort!\n";
			LOG->flush();
			close(LOG);
			exit(-1);
		}
	}
	my $ppp = waitpid($pid, 0);
	my $ret = $?;
	if ($ret != 0) {
		if ($ret == -1) {
			print LOG "tRNAscan-SE failed to run\n";
			LOG->flush();
			close(LOG);
			exit(-1); # child process fails and exits
		} else {
			my $exitcode = $ret >> 8;
			print LOG "tRNAscan-SE failed with exit status $exitcode\n";
			LOG->flush();
			close(LOG);
			exit(-1); # child process fails and exits
		}
	}
    
    my $trnascan_done = time;
    my $time = $trnascan_done - $trnascan_start;
    system("echo 'tRNAscan-SE took $time seconds' >> $log_file");
    system("touch tRNAscan.done") if (-e "tRNAscan.out");

    system("echo   'find tmRNA sequences ...' >> $log_file");
    $ret = system("aragorn -m -o tmRNA_aragorn.out $num.fna >> $log_file 2>&1");
    if ($ret != 0) {
    	if ($ret == -1) {
				print LOG "aragorn failed to run\n";
				LOG->flush();
				close(LOG);
				exit(-1); # child process fails and exits
    	} else {
    		my $exitcode = $ret >> 8;
				print LOG "aragorn failed with exit status $exitcode\n";
				LOG->flush();
				close(LOG);
    		exit(-1); # child process fails and exits
    	}
    }

    my $aragorn_done = time;
    $time = $aragorn_done - $trnascan_done;
    system("echo 'aragorn took $time s' >> $log_file");
	
	system ("echo	'find rRNA sequences ...' >> $log_file");
	$ret = system("barrnap --quiet --outseq rRNA_barrnap.out $num.fna >> $log_file 2>&1");
		if ($ret != 0) {
			if ($ret == -1) {
				print LOG "barrnap failed to run\n";
				LOG->flush();
				close(LOG);
				exit(-1); # child process fails and exits
			} else {
				my $exitcode = $ret >> 8;
				print LOG "barrnap failed with exit status $exitcode\n";
				LOG->flush();
				close(LOG);
				exit(-1); # child process fails and exits
			}
		}

	my $barrnap_done = time;
	$time = $barrnap_done - $aragorn_done;
	system("echo 'barrnap took $time s' >> $log_file");

    #extract RNA
    system("echo '$scripts_dir/extract_RNA.pl $num extract_RNA_result.txt.tmp $flag' >> $log_file");
    $ret = system("perl $scripts_dir/extract_RNA.pl $num extract_RNA_result.txt.tmp $flag");
    if ($ret != 0) {
    	if ($ret == -1) {
				print LOG "extract_RNA.pl failed to run\n";
				LOG->flush();
				close(LOG);
				exit(-1); # child process fails and exits
    	} else {
    		my $exitcode = $ret >> 8;
				print LOG "extract_RNA.pl failed with exit status $exitcode\n";
				LOG->flush();
				close(LOG);
    		exit(-1); # child process fails and exits
    	}
    }
    
    system("echo '$scripts_dir/make_RNA_png_input.pl  extract_RNA_result.txt.tmp  RNA_output.out' >> $log_file");
    $ret = system("perl $scripts_dir/make_RNA_png_input.pl  extract_RNA_result.txt.tmp  RNA_output.out");
    if ($ret != 0) {
    	if ($ret == -1) {
				print LOG "make_RNA_png_input.pl failed to run\n";
				LOG->flush();
				close(LOG);
				exit(-1); # child process fails and exits
    	} else {
    		my $exitcode = $ret >> 8;
				print LOG "make_RNA_png_input.pl failed with exit status $exitcode\n";
				LOG->flush();
				close(LOG);
    		exit(-1); # child process fails and exits
    	}
    }
}

sub find_running_case_file{
	my ($running_array) = @_;
	# print "length of running_array= ". scalar(@$running_array). "\n";
	my $running_file = '';
	for(my $i=0; $i < scalar(@$running_array); $i++){
		my $running_file = $$running_array[$i];
		if (-e $running_file){
    	# check the status of running.txt in tolerate time , if over , kill it
    		my $data = `cat $running_file`;
    		my ($last_num) = $data=~/\S+\s+(\S+)/s;
    		my $time= `ls -l $running_file`;
    		my $now_time = `date`;
    		my ($hour, $min)=$time=~/ (\d+):(\d+)/s;
    		my ($hour1,$min1)=$now_time=~/ (\d+):(\d+)/s;
    		$time=$hour*60+$min; $now_time=$hour1*60+$min1;
			$now_time += 24*60  if ($time > $now_time);
    		if ($now_time - $time >$last_case_tolerate_time){
        		my $msg="Over $last_case_tolerate_time mins, h:$hour, m:$min, h1:$hour1, m1:$min1, old_time:$time, now_time:$now_time, $last_num is got stuck. kill it ";
        		put_back_case_clean_process_exit($last_num,  $msg, $running_file);
    		}
		}
		if (-e $running_file){
    		print "$running_file exist!!Next\n";
			$running_file = '';
    		next;
		}else{
			return $running_file;
		}

	}# end of for  
	return $running_file;
}

# Derive a 2-letter enclosing directory name from the given job id. The purpose is to
# avoid creating more job directories at one level of the file system than are allowed,
# so we put the job directory within the 2-letter enclosing directory.
sub get_enclosing_folder_from_job_id{
	my ($dir) = @_;
	
	my $enclosing_dir;
	if ($dir =~ /^ZZ_(..)/) {
		$enclosing_dir = $1;
	} elsif (length($dir) >= 2) {
		if ($dir =~ /^(..)/) {
			$enclosing_dir = $1;
		} else {
			print STDERR "Could not derive enclosing folder name from job id $dir\n";
			exit(-1);
		}
	} else {
		print STDERR "Could not derive enclosing folder name from job id $dir\n";
		exit(-1);
	}
	
	return($enclosing_dir);
}

# Subroutine to find the common element in the names of the contigs.
# For example, for the given file:
# 	SGQG01000020.1,Pectobacterium,carotovorum,subsp.,carotovorum,strain,Ec-006,NODE_20_length_10311_cov_7.781415,,whole,genome,shotgun,sequence	1	10311	10311
#	SGQG01000021.1,Pectobacterium,carotovorum,subsp.,carotovorum,strain,Ec-006,NODE_21_length_8273_cov_164.985237,,whole,genome,shotgun,sequence	10312	18584	8273
# We would return:
# Pectobacterium carotovorum subsp. carotovorum strain Ec-006 whole genome shotgun sequence
sub find_common_element {
	my ($contig_file) = @_;
	my $common_element = '';
	my %common_elem_hash = ();

	open (IN, $contig_file) || return "Genome; Raw Sequence";
	my $first_line = <IN>;
	chomp($first_line);
	my @fields = split(/\t/, $first_line);
	my $description = $fields[0];
	my @first_words = split(/,/, $description);

	# Iterate each line of the contig_positions file.
	while (my $line = <IN>) {
		chomp($line);
		my @fields = split(/\t/, $line);
		my $description = $fields[0];
		my @words = split(/,/, $description);

		# Iterate each word in the description.
		for (my $i = 0; $i < scalar(@first_words); $i++) {
			if ($first_words[$i] eq $words[$i]) {
				$common_elem_hash{$i} = 1;
			}
			else {
				$common_elem_hash{$i} = 0;
			}
		}
	}
	close IN;

	# Iterate the hash and build the name from common element.
	my $common_elem_count = 0;
	foreach my $key (sort {$a<=>$b} keys %common_elem_hash) {
		if ($common_elem_hash{$key} == 1) {

			# If the word is empty string, then it's likely a comma.
			if ($first_words[$key] eq '') {
				$common_element =~ s/\s$/, /;
				next;
			}

			$common_element .= $first_words[$key] . " ";
			$common_elem_count++;
		}
	}
	if ($common_elem_count < 5) {
		return $description;
	}
	else {
		return $common_element;
	}
}

# Subroutine to check if the contig files are all in correct format.
# Iterate line by line, skipping over nucleotide sequences. 
# If the code detect header line that does not start with '>' identifier, then return 0.
# Otherwise, the contig headers are all in correct format, return 1.
sub check_contig_headers {
	my ($fna_file) = @_;

	open (IN, $fna_file) || return 0;

	while (my $line = <IN>) {
		chomp($line);
		unless ($line =~ /^[ACGTURYSWKMBDHVN\.\-]+$/) { # IUPAC nucleotide codes
			unless ($line =~ /^>/) {
				close IN;
				return 0;
			}
		}
	}

	close IN;
	return 1;
}

# Kill forked processes and children of forked processes when this script receives a TERM
# signal.
#
# The 'use sigtrap' declaration above defines that this subroutine is to be called when
# this script receives a TERM signal. Such a signal may be sent by the PHASTEST Rails app
# due to a timeout.
sub handle_term {
	open (LOG, ">>$log_file") || die "Could not open file $log_file: $!\n";
	print LOG "phastest.pl received TERM signal\n";
	print "phastest.pl received TERM signal\n";
	if (scalar(@children) > 0) {
		print LOG "Killing process groups of " . scalar(@children) .  " forked processes...\n";
	} else {
		print LOG "No forks of phastest.pl that would need to be terminated.\n";
	}
	LOG->flush();
	close(LOG);

	for (my $i = 0; $i < scalar(@children); $i++) {
		kill -9, $children[$i];
			# Use minus sign to kill all processes with PGID == $children[$i]. We assume all
			# child processes of the forked processes share the same PGID.

		open (LOG, ">>$log_file") || die "Could not open file $log_file: $!\n";
		print LOG "Killed forked process group with PGID " . $children[$i] . "\n";
		LOG->flush();
		close(LOG);
	}
	exit(1);
}