#!/usr/bin/perl -w

# Collect job runtime stats from job log files, including from compressed job directories.
# Intended to be run on the backend cluster.
#
# When run on Botha1 in May 2020, when run on 580,544 input job IDs, timing data was
# found for 562,037 jobs, and the script took 17 h 38 min to run.

use strict;

my $infile = $ARGV[0]; # list of JOB ids
my $outfile = $ARGV[1];

my $phaster_home = $ENV{'PHASTEST_CLUSTER_HOME'};
if (!defined($phaster_home)) {
	print STDERR "ERROR: Environment variable PHASTER_CLUSTER_HOME is not defined.\n";
	exit(1);
}

open(OUT, '>', $outfile) or die "Could not open $outfile";

# Print header
# Header names should match column names in PHASTER's runtimes database table.
print OUT "job_id\tglimmer\tfraggenescan\tblast_virus\tblast_bac\ttotal\n";

open(IN, '<', $infile) or die "Could not open $infile";
while(<IN>) {
	my $job_id = $_;
	chomp($job_id);
	next if ($job_id eq '');
	
	my $encl_dir = ''; # 2-letter enclosing dir name
	if ($job_id =~ /^ZZ_(\w\w)\w+/) {
		$encl_dir = $1;
	} else {
		$encl_dir = substr($job_id, 0, 2);
	}
	
	my $log_filename = "${job_id}.log";
	
	
	# Obtain log file contents for current job.
	my $content = ''; # log file contents for current job
	my $tgz_path = "${phaster_home}/JOBS/${encl_dir}/${job_id}.tz";
	if (!(-e $tgz_path)) {
		# .tgz file for job id does not exist. Check to see if non-compressed job dir exists.
		my $log_file_path = "${phaster_home}/JOBS/${encl_dir}/${job_id}/${log_filename}";
		if (!(-e $log_file_path)) {
			next; # Non-compressed log file does not exist either. Skip job id.
		} else {
			# Slurp the log file contents.
			open my $fh, '<', $log_file_path or die "Can't open file $!";
			$content = do { local $/; <$fh> };
			close($fh);
		}
	} else {
		# Load log file contents from the .tgz file for the job.
# 		my $tar = Archive::Tar->new;
# 		$tar->read($tgz_path);
		my $log_file_path = './' . $job_id . '/' . $log_filename;
# 		if ($tar->contains_file($log_file_path)) {
# 			my @files = $tar->get_files($log_file_path);
# 			$content = $files[0]->get_content();
# 		}
		
		my $cmd = "tar -xOf ${tgz_path} ${log_file_path}";
		$content = `$cmd`;
		next if $?; # Skip if tar command failed.
	}
	
	
	# Initialize hash of timing values.
	my $times = {};
	$times->{'start'} = '';
	$times->{'gene_finding'} = '';
	$times->{'glimmer'} = '';
	$times->{'fraggenescan'} = '';
	$times->{'ppt'} = '';
	$times->{'faa'} = '';
	$times->{'before_tRNAscan'} = '';
	$times->{'phage_finder_tRNA_tmRNA_done_at'} = '';
	$times->{'phage_finder_tRNA_tmRNA'} = '';
	$times->{'copy_pep'} = '';
	$times->{'copy_blast'} = '';
	$times->{'blast_virus'} = '';
	$times->{'phage_finder_and_checks_done_at'} = '';
	$times->{'scan_start'} = '';
	$times->{'scan'} = '';
	$times->{'scan_done_at'} = '';
	$times->{'blast_bac_start'} = '';
	$times->{'mkdir'} = '';
	$times->{'copy_non_hit_pro_region'} = '';
	$times->{'call_blast_parallel_bac'} = '';
	$times->{'copy_ncbi_out'} = '';
	$times->{'call_remote_blast'} = '';
	$times->{'blast_bac'} = '';
	$times->{'blast_bac_done_at'} = '';
	$times->{'read_vir_header'} = '';
	$times->{'read_bac_header'} = '';
	$times->{'annotation'} = '';
	$times->{'annotation_plus_waiting'} = '';
	$times->{'annotation_done_at'} = '';
	$times->{'extract_protein'} = '';
	$times->{'get_true_region'} = '';
	$times->{'png'} = '';
	$times->{'total'} = '';
	
	
	# Parse log file for timing messages.
	if ($content =~ /Start (?:Glimmer|FragGeneScan) at (\d+) sec/) {
		$times->{'start'} = $1;
	}
	if ($content =~ /(?:Glimmer|FragGeneScan) run time = (\d+) sec/) {
		$times->{'gene_finding'} = $1;
		if ($content =~ /Glimmer run time = (\d+) sec/) {
			$times->{'glimmer'} = $1;
		}
	if ($content =~ /FragGeneScan run time = (\d+) sec/) {
			$times->{'fraggenescan'} = $1;
		}
	}
	if ($content =~ /Generating ppt file took (\d+) sec/) {
		$times->{'ppt'} = $1;
	}
	if ($content =~ /Generating faa file took (\d+) sec/) {
		$times->{'faa'} = $1;
	}
	if ($content =~ /Elapsed before tRNA scanning = (\d+) sec/) {
		$times->{'before_tRNAscan'} = $1;
	}
	if ($content =~ /phage_finder.sh and tRNA_tmRNA() done at (\d+) sec/) {
		$times->{'phage_finder_tRNA_tmRNA_done_at'} = $1;
	}
	if ($content =~ /phage_finder.sh and tRNA_tmRNA() took (\d+) sec/) {
		$times->{'phage_finder_tRNA_tmRNA'} = $1;
	}
	if ($content =~ /copy pep file to cluster took (\d+) sec/) {
		$times->{'copy_pep'} = $1;
	}
	if ($content =~ /copy BLAST results from cluster took (\d+) sec/) {
		$times->{'copy_blast'} = $1;
	}
	if ($content =~ /Parallel BLASTing ${job_id}.faa against the Phage virus DB took (\d+) seconds/) {
		$times->{'blast_virus'} = $1;
	}
	if ($content =~ /phage_finder and checks done at (\d+) sec/) {
		$times->{'phage_finder_and_checks_done_at'} = $1;
	}
	if ($content =~ /scan.pl started at (\d+) sec/) {
		$times->{'scan_start'} = $1;
	}
	if ($content =~ /scan.pl took (\d+) sec/) {
		$times->{'scan'} = $1;
	}
	if ($content =~ /scan.pl done at (\d+) sec/) {
		$times->{'scan_done_at'} = $1;
	}
	if ($content =~ /Start parallel BLASTing non-hit regions at (\d+) sec/) {
		$times->{'blast_bac_start'} = $1;
	}
	if ($content =~ /call_remote_blast.sh: mkdir on cluster via SSH took (\d+) sec/) {
		$times->{'mkdir'} = $1;
	}
	if ($content =~ /call_remote_blast.sh: copy ..\/${job_id}.faa.non_hit_pro_region to cluster took (\d+) sec/) {
		$times->{'copy_non_hit_pro_region'} = $1;
	}
	if ($content =~ /call_remote_blast.sh: run call_blast_parallel.pl on cluster via SSH took (\d+) sec/) {
		$times->{'call_blast_parallel_bac'} = $1;
	}
	if ($content =~ /call_remote_blast.sh: copy ..\/ncbi.out.non_hit_pro_region from cluster took (\d+) sec/) {
		$times->{'copy_ncbi_out'} = $1;
	}
	if ($content =~ /call_remote_blast.sh took (\d+) sec/) {
		$times->{'call_remote_blast'} = $1;
	}
	if ($content =~ /Parallel BLASTing non-hit regions took (\d+) sec/) {
		$times->{'blast_bac'} = $1;
	}
	if ($content =~ /Parallel BLASTing non-hit regions done at (\d+) sec/) {
		$times->{'blast_bac_done_at'} = $1;
	}
	if ($content =~ /read in \/apps\/phaster\/phaster-app\/DB\/prophage_virus_header_lines.db, time (\d+) seconds/) {
		$times->{'read_vir_header'} = $1;
	}
	if ($content =~ /read in \/apps\/phaster\/phaster-app\/DB\/bacteria_all_select_header_lines.db , time (\d+) seconds/) {
		$times->{'read_bac_header'} = $1;
	}
	if ($content =~ /Finish annotation.pl in (\d+) seconds/) {
		$times->{'annotation'} = $1;
	}
	if ($content =~ /annotation.pl plus waiting took (\d+) sec/) {
		$times->{'annotation_plus_waiting'} = $1;
	}
	if ($content =~ /annotation.pl done at (\d+) sec/) {
		$times->{'annotation_done_at'} = $1;
	}
	if ($content =~ /extract_protein.pl took (\d+) sec/) {
		$times->{'extract_protein'} = $1;
	}
	if ($content =~ /get_true_region.pl took (\d+) sec/) {
		$times->{'get_true_region'} = $1;
	}
	if ($content =~ /make_png.pl took (\d+) sec/) {
		$times->{'png'} = $1;
	}
	if ($content =~ /Program finished, taking (\d+) seconds!/) {
		$times->{'total'} = $1;
	}
	
	# Print out timing values for current job.
	if ($times->{'total'} ne '') {
		print OUT $job_id . "\t" . $times->{'glimmer'} . "\t" . $times->{'fraggenescan'} . "\t" . $times->{'blast_virus'} . "\t" . $times->{'blast_bac'} . "\t" . $times->{'total'} . "\n";
	}
		
}
close(IN);
close(OUT);
