#!/usr/bin/perl

# Script to delete unneeded intermediate files within submission directories.
#
# Note: This script can take many hours (more than 7, at least).
#
# David Arndt, Jun 2018

use strict;

my $days_old_threshold = 30.0; # Delete intermediate files for submissions older than this many days.

# Intermatidate files (full names of files)
my @intermed_full = (
	'tRNAscan.out',
	'tmRNA_aragorn.out',
	'extract_RNA_result.txt.tmp',
	'ncbi.out',
	'ncbi.out.non_hit_pro_region',
	'true_defective_prophage.txt',
	'success.txt'
);

# Intermediate files (files with job id prefixed)
my @intermed_with_job_id_prefix = (
	'.predict', '.ptt', '.faa', '.faa.non_hit_pro_region'
);

my $total_initial_size = 0;
	# total initial size of job directories that contain intermediate files, in bytes
my $total_size_freed = 0; # total size of intermediate files deleted, in bytes
my $total_submission_dirs = 0; # total number of submission directories older than threshold
my $total_dirs_reduced = 0; # number of job directories from which intermediate files deleted


if ( !defined( $ENV{PHASTEST_CLUSTER_HOME} ) ) {
	die 'The PHASTEST_CLUSTER_HOME enviroment variable is not set\n';
}

my $jobs_dir = "$ENV{PHASTEST_CLUSTER_HOME}/JOBS";

print "$jobs_dir\n";

opendir(JOBS, $jobs_dir);
my @encl_dirs = readdir(JOBS);
closedir(JOBS);

foreach my $encl_dirname (@encl_dirs) # Iterate through 2-letter enclosing directories.
{
	# skip . and ..
	next if($encl_dirname =~ /^\.$/);
	next if($encl_dirname =~ /^\.\.$/);
	
	next if(length($encl_dirname) != 2);
	
	my $encl_path = $jobs_dir . '/' . $encl_dirname;
	
	if (-d $encl_path) {
		
		print "  $encl_path\n";
		
		opendir(ENCL, $encl_path);
		my @submission_dirnames = readdir(ENCL);
		closedir(ENCL);
		
		foreach my $submission_dirname (@submission_dirnames) # Iterate through submission directories.
		{
			# skip . and ..
			next if($submission_dirname =~ /^\.$/);
			next if($submission_dirname =~ /^\.\.$/);
			
			my $submission_path = $encl_path . '/' . $submission_dirname;
			
			if (-d $submission_path) {
				my $days_old = -M $submission_path; # Script start time minus file modification time (a.k.a. file modification age), in days.
				if ($days_old > $days_old_threshold) {
					$total_submission_dirs += 1;
					delete_intermed($submission_path, $submission_dirname);
				}
			}
		}
	}
}


# Report space freed
my $initial_gb = $total_initial_size / (1024**3);
my $freed_gb = $total_size_freed / (1024**3);
my $percent_freed = ($total_size_freed/$total_initial_size)*100.0;

print "Intermediate files removed from $total_dirs_reduced out of $total_submission_dirs directories.\n";
printf "$total_size_freed of $total_initial_size bytes freed (%.2f of %.2f GB), or %.2f percent.\n",
		$freed_gb, $initial_gb, $percent_freed;



sub delete_intermed {
	my ($submission_path, $job_id) = @_;
	
# 	print "    $submission_path $job_id\n";
	
	my $du = `du -bs $submission_path`;
	my $intial_bytes = 0;
	if ($du =~ /^(\d+)/) {
		$intial_bytes = $1;
	} else {
		die "\'du -bs $submission_path\' failed\n";
	}
	print "$intial_bytes $submission_path\n";
	
	# Create array of all intermediate files.
	my @intermed = @intermed_full;
	foreach my $suffix (@intermed_with_job_id_prefix) {
		push @intermed, ($job_id . $suffix)
	}
	
	# Delete intermediate files and record how much space freed.
	my $found_intermed_file = 0;
	my $bytes_freed = 0; # Bytes freed in current submission directory.
	foreach my $filename (@intermed) {
		my $path = $submission_path . '/' . $filename;
		if (-e $path) {
			$found_intermed_file = 1;
			my $size = (stat $path)[7];
			$bytes_freed += $size;
			system("rm -f $path");
		}
	}
	
	if ($found_intermed_file) {
		$total_dirs_reduced += 1;
		$total_initial_size += $intial_bytes;
		$total_size_freed += $bytes_freed;
	}
	
}

