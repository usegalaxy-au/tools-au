#!/usr/bin/perl -w

# Write links for amino acid sequences of genes of representative bacterial genomes
# to protein_file.

use strict;

my $tmp_dir = "/home/prion/phastest-app/DB/temp_bac_select";

chdir $tmp_dir;

my $cmd = q{wget 'ftp://ftp.ncbi.nlm.nih.gov/genomes/refseq/bacteria/assembly_summary.txt'};
system($cmd);

open(IN, "assembly_summary.txt") or die "Cannot open file";

my $output="protein_file";
open(OUT, ">$output") or die "Cannot write $output";

# $count = 0;

# Retrieve current bacterial genomes (only representative genomes)
my $done_header = 0;
my $prev = '';
my $ftp_path_idx = -1;
while(<IN>) {
	chomp ($_);
	
	# Parse header to determine the correct column index for FTP links.
	if (!$done_header) {
		if ($_ !~ /^#/) {
			# parse last comment line for headers
			$prev =~ s/^# *//;
			my @header_elems = split("\t", $prev);
			for (my $i = 0; $i < scalar(@header_elems); $i++) {
				if ($header_elems[$i] eq 'ftp_path') {
					$ftp_path_idx = $i;
					$done_header = 1;
					next;
				}
			}
			if ($ftp_path_idx == -1) {
				print STDERR "Could not parse header 'ftp_path' from assembly_summary.txt! Aborting.\n";
				exit(1);
			}
		} else {
			$prev = $_;
			next;
		}
	}
	
	# Extract FTP links and write them to a file.
	if($_=~ m/representative/){

		my @data = split('\t', $_);
		my $link = $data[$ftp_path_idx];
		my @dirs = split('/', $link);
		my $last = $dirs[-1];
		my $full_link = $link."/".$last."_protein.faa.gz";

		print OUT $full_link."\n";

		# $count ++;
	}

}

close IN;
close OUT;

$cmd = q{rm assembly_summary.txt};
system($cmd);

