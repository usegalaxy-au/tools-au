#!/usr/bin/perl

########################################################################################
#
# Script to find BLAST errors for PHASTER jobs.
#
# David Arndt, Nov 2016
#
########################################################################################

use strict;

my @blast_dirs = ('blast_v', 'blast_b');
my $base_path = '/home/prion/phaster-app/JOBS';

my $errs = {};

open(OUT, '>', 'blast_errors.txt');

opendir my $dh, $base_path or die "$0: opendir: $!";
my @job_abbrev_dirs = grep {-d "$base_path/$_" && ! /^\.{1,2}$/} readdir($dh);

for (my $i = 0; $i < scalar(@job_abbrev_dirs); $i++) {
	my $job_abbrev_dir = $job_abbrev_dirs[$i];
	#print $job_abbrev_dir . "\n";
	
	my $path = "$base_path/$job_abbrev_dir";
	#print $path . "\n";
	
	opendir my $dh2, $path or die "$0: opendir: $!";
	my @job_dirs = grep {-d "$path/$_" && ! /^\.{1,2}$/} readdir($dh2);
	
	for (my $j = 0; $j < scalar(@job_dirs); $j++) {
		my $job_dir = $job_dirs[$j];
		print $job_dir . "\n";
		
		my $mtime = '';
		my $has_errors = 0;
		$errs = {};
		
		for (my $k = 0; $k < scalar(@blast_dirs); $k++) {
			my $blast_dir = $blast_dirs[$k];
			
			$path = "$base_path/$job_abbrev_dir/$job_dir/tmp/$blast_dir";
			
			if (-d $path) {
				#print $path . "\n";
				opendir(DIR, $path);
				my @files = grep(/^single_blast\.pl\.p?e.*/,readdir(DIR));
				closedir(DIR);
			
				foreach my $filename (@files) {
					my $file_path = "$path/$filename";
					#print "$file_path\n";
					if (-z $file_path) {
						#print "empty\n";
					} else {
						open (IN, '<', $file_path);
						while (<IN>) {
							my $line = $_;
							chomp($line);
							if (!($line eq 'blastp: /lib64/libz.so.1: no version information available (required by blastp)')) {
								#print $line . "\n";
								$errs->{$line} = 1;
								$has_errors = 1;
							}
						}
						my $mtime_tmp = (stat(IN))[9];
						if ($mtime eq '' || $mtime_tmp < $mtime) {
							$mtime = $mtime_tmp;
						}
						close(IN);
					}
				}
				closedir(DIR);
				
			}
		}
		
		# Print to TSV file
		print OUT $job_dir . "\t";
		print OUT $mtime . "\t";
		print OUT localtime($mtime) . "\t";
		if ($has_errors) {
			foreach (keys %{$errs}){
				print OUT $_ . ";";
			}
		}
		print OUT "\n";
		
	}
	closedir($dh2);
	
}
closedir($dh);
close(OUT);
