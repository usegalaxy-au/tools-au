#!/usr/bin/perl -w

# this program will input .faa file and phpico.txt file or phmedio.txt or phregions.txt file
# and bases on the  .txt file  to filter the .faa file. What is needed is the non phage blast hit part in .txt file.
# The output file should be the filtered info in .faa format.
#
# This script can either generate non-hit genes for prophage region only (anno_flag = 0), or for entire query genome
# (anno_flag = 1).
#
# Usage: $script_dir/non_hit_region_pro_to_faa.pl <.faa query> <_phmedio.txt> <output file name> <annotation flag>

use Bio::SeqIO;

my $anno_flag = $ARGV[3];

if (@ARGV!=4){
	print "Usage : perl non_hit_region_pro_to_faa.pl  <.faa file > <.txt file > <ouput_file> <flag> \n";
	exit;
}

open(IN, $ARGV[1]) or die "Cannot open $ARGV[1]"; # Opens *_phmedio.txt file

my @hits = ();	# Only used if anno_flag == 1.
my @bact = ();	# Only used if anno_flag == 0.

while (<IN>) {
	# Looks for all regions identified in the phmedio.txt.
	# 1499624    01454              gi|1454|ref|NP_536838.1|, TAG = PHAGE_Haemop_HP2_NC_003315, E-VALUE = 5.43e-24
	if ($_=~/^\d+\s+(\d+).*\|ref\|/ && $anno_flag == 1){
		push @hits, $1;
	}

	# Look for bacterial protein within the prophage region.
	# 1501877    01458              [ANNO] -; PP_01458
	if ($_=~/^\d+\s+(\d+).*\[ANNO\]/ && $anno_flag == 0) {
		push @bact, $1;
	}
}
close IN;

if ($anno_flag == 0 && @bact == 0) {
	print "No bacterial protein found in the prophage region. Exiting.\n";
	system("touch $ARGV[2]");
	exit;
}

my ($gi, $flag);
my $input 	= Bio::SeqIO->new(-file   => "$ARGV[0]",
							"-format" => "fasta");
my $output 	= Bio::SeqIO->new(-file   => "> $ARGV[2]",
							"-format" => "fasta");

if ($anno_flag == 1) {
	while (my $seq = $input->next_seq) {
		$flag = 1;
		$gi = $1 if $seq->id =~ /^gi\|(\d+)\|/;	# Local GI number from .faa file.
		foreach my $hit (@hits) {
			if ($gi eq $hit) {
				$flag = 0;		# Local GI is defined as phage hits, no need to add to non_hit_pro_region.
				last;
			}
		}
		if ($flag) {
			#print "Writing $gi\n";
			$output->write_seq($seq);
		}
	}
}
else {
	while (my $seq = $input->next_seq) {
		$flag = 1;
		$gi = $1 if $seq->id =~ /^gi\|(\d+)\|/;	# Local GI number from .faa file.

		foreach my $hit (@bact) {
			if ($gi eq $hit) {
				$flag = 1;		# Local GI found within the prophage region, add to non_hit_pro_region.
				last;
			}
			else {
				$flag = 0;		# GI number is not found within the prophage region, exclude from non_hit_pro_region.
			}
		}
		if ($flag) {
			$output->write_seq($seq);
		}
	}
}

exit;