#!/usr/bin/perl -w

##########################################################################################
#
# Script to count the number of amino acid residues (and number of sequences) in a FASTA
# file, such as a BLAST DB. The number of amino acids is used when specifying the database
# size to blastp (-dbsize option).
#
# David Arndt, Jan 2016
#
##########################################################################################

use strict;

my $num_seqs = 0;
my $num_aa = 0;

my $fasta_filename = $ARGV[0];

open(IN, $fasta_filename) or die "Cannot open $fasta_filename";
while (my $line = <IN>){
	if ($line =~ /^>/) {
		$num_seqs++;
	} elsif ($line =~ /([A-Z]+)/) {
		# Note: In addition to the standard amino acids (ACDEFGHIKLMNPQRSTVWY), a large
		# bacterial sequence database was found to contain sequences with other letters:
		# BJOUXZ. All of these are counted here.
		$num_aa += length($1);
	}
}
close(IN);
print("$num_seqs sequences and $num_aa amino acids in file.\n");
