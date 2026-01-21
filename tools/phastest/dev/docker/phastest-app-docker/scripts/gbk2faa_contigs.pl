#!/usr/bin/perl

# Author :	Scott Han
# Date :	July 28, 2022
#
# Similar to gbk2faa.pl code, but with minor alteration for WGS-based sequences.
# If possible, look into combining this with normal gbk2faa.pl code?
# 
# Generates .faa output to the job directory.

my $input = $ARGV[0];
my $fna_file = $ARGV[1];
my $contig_loc = $ARGV[2];

my $fna_seq = `cat $fna_file`;
$fna_seq =~ s/>gi.*?\n//;
$fna_seq =~ s/\n//g;

my $faa_filename=$input;
$faa_filename =~ s/\.gbk//;
$faa_filename.=".faa";

gbk2faa($input,$faa_filename);
if (!-s $faa_filename){
    print STDERR "No  $faa_filename generated!\n";
}else{
    print "$faa_filename generated!\n";
}

exit;
	
sub gbk2faa{
	my ($input,$output)=@_;
	my $organism=''; #organism
	my $gi='NONE'; #db_xref:"GI
	my $protein_id='NONE'; #protein_id
	my $product='NONE'; #product, protein name
	my $seq='NONE'; #amino acid sequence
	my $location ='NONE'; # coplement(114..567) pr 114..567

	my $gbk='';
	my @draft=();

	# Get the GenBank data into an array from a file
	$gbk = `cat $input`;
	if($gbk=~/\/organism="(.*?)"/s) {
		$organism=$1;
		$organism=~s/\n//g;
		$organism=~s/\[.*?\]//g;
		$organism=~s/\s\s+/ /g;
		$organism=~s/\s+$//;
    }
	
	my @lines = split("\n", $gbk);
	my $flag = 0;
	my $line = "";
	my @draft;

	foreach(@lines){ 
		if ($_ =~ /^ACCESSION/) {
			push @draft, $_;
			$flag = 0;
		}
		elsif ($_ =~ /^\s+CDS\s+(join|\<|\d|complement)/ && !$flag) {
			$flag = 1;
		}
		elsif ($_ =~ /^\s+CDS\s+(join|\<|\d|complement)/ && $flag) {
			push @draft, $line if $line ne "";
			$line = "";
		}
		elsif ($_ =~ /^\s+gene\s+(join|\<|\d|complement)/ && $flag) {
			$flag = 0;
			push @draft, $line if $line ne "";
			$line = "";
		}
		elsif ($_ =~ /^ORIGIN/ && $flag) {
			$flag = 0;
			push @draft, $line if $line ne "";
			$line = "";
		}
		# If flag == 1, grab everything between "CDS" header and "gene" header.
		if ($flag) {
			$line .= $_;
		}
	}

	open(OUT,">$output");
	my $curr_loc;
	my $gi_count = 0;
	my $region_count = 0;

	@lines = split("\n", `cat $contig_loc`);

	foreach my $rec (@draft){
		$protein_id='NONE';
		$product='NONE';
		$seq='NONE';
		$location ='NONE';
		$gi ='NONE';

		# Retrieve accession number and move onto next element of array.
		if ($rec =~ /^ACCESSION/) {
			$curr_loc = $1 if $lines[$region_count] =~ /^\S+\s+(\d+)\s/;
			$region_count++;
			next;
		}
		# Warning: This regex format is slightly different than what normal .gbk uses.
		if ($rec=~/^\s+(CDS)\s+(.*?)\s+/s ) {
			$location = $2;
			$location =~s/\n//g;
			$location =~s/\s//g;
			$location =~s/>//g;
			$location =~s/<//g;
			$location =~s/join\((\d+)(?:\,|\.).*(?:\,|\.)(\d+)(?:\)|\,)/$1\.\.$2/g;

			# Adjust for the different contig position.
			my ($l, $r) = ($1, $2) if $location =~ /(\d+)\.\.(\d+)/;
			$l += ($curr_loc - 1); 
			$r += ($curr_loc - 1);
			$location =~ s/\d+\.\.\d+/$l\.\.$r/g;
			$location =~ s/\((\d+\.\.\d+)$/\($1\)/g;
		}
		if($rec=~/product="(.*?)"/) {
			$product=$1;
			$product=~s/\n\s+/ /gs;
			$product=~s/[ \t]{2,}/ /gs;
		}
		if($rec=~/protein_id="(.*?)"/) {
			$protein_id=$1;
        }
		if($rec=~/translation="(.*?)"/) {
			$seq = $1;
			$seq =~s/[\s\n]//sg;
		}
		if ($seq eq "NONE" && $location ne 'NONE'){
			my $sub_seq = '';
			if ($location =~/complement\((\d+)\.\.(\d+)\)/){
				$sub_seq = substr($fna_seq, $1-1, $2-$1+1);
				$sub_seq = reverse($sub_seq);
        		$sub_seq =~tr/[ATCG]/[TAGC]/;
			}elsif ($location =~/(\d+)\.\.(\d+)/){
				$sub_seq = substr($fna_seq, $1-1, $2-$1+1);
			}
			if ($sub_seq eq ''){
				my $start = $1 + $startpos; my $end = $2 + $startpos;
				my $length = length($fna_seq);
				if ($end < $start){
					print STDERR "No substr from fna seq of length $length location $location , weird,  skip it!!!\n";
					next; # skip the werid format location, normally it is cross the end and back to the start of circular DNA.
				}
			}
			$seq = change_to_pro_seq($sub_seq);
		}
		if ($seq eq "" or $seq eq 'NONE'){
            next;
        }
        $protein_id =~s/\n//g;
		$protein_id =~s/\s+/ /g;
		
		$gi_count++;
		$gi_count="0$gi_count" if (length($gi_count) == 4);
		$gi_count="00$gi_count" if (length($gi_count) == 3);
		$gi_count="000$gi_count" if (length($gi_count) == 2);
		$gi_count="0000$gi_count" if (length($gi_count) == 1);
		print OUT ">gi|$gi_count|ref|$protein_id| $product, $location [$organism]\n$seq\n";
	}
			
	close OUT;
	return 1;
}

# change gene sequence to protein sequence
sub change_to_pro_seq{
    my $sub_seq = shift;
    my $jumps = length($sub_seq)/3;
    my $seq ='';
    for(my $i =0; $i < $jumps ; $i++){
        my $code3 = substr($sub_seq, $i*3, 3);
        my $code1 = change_to_single_pro_code($code3);
        $seq .= $code1;
    }
    return $seq;
}
# change codon into single amino acid name
sub change_to_single_pro_code{
    my $codon = shift;
    $codon=~s/TTT/F/; $codon=~s/TTC/F/;$codon=~s/TTA/L/;$codon=~s/TTG/L/;$codon=~s/TCT/S/;$codon=~s/TCC/S/;$codon=~s/TCA/S/;$codon=~s/TCG/S/;
    $codon=~s/TAT/Y/; $codon=~s/TAC/Y/;$codon=~s/TAA//;$codon=~s/TAG//;$codon=~s/TGT/C/;$codon=~s/TGC/C/;$codon=~s/TGA//;$codon=~s/TGG/W/;
    $codon=~s/CTT/L/; $codon=~s/CTC/L/;$codon=~s/CTA/L/;$codon=~s/CTG/L/;$codon=~s/CCT/P/;$codon=~s/CCC/P/;$codon=~s/CCA/P/;$codon=~s/CCG/P/;
    $codon=~s/CAT/H/; $codon=~s/CAC/H/;$codon=~s/CAA/Q/;$codon=~s/CAG/Q/;$codon=~s/CGT/R/;$codon=~s/CGC/R/;$codon=~s/CGA/R/;$codon=~s/CGG/R/;
    $codon=~s/ATT/I/; $codon=~s/ATC/I/;$codon=~s/ATA/I/;$codon=~s/ATG/M/;$codon=~s/ACT/T/;$codon=~s/ACC/T/;$codon=~s/ACA/T/;$codon=~s/ACG/T/;
    $codon=~s/AAT/N/; $codon=~s/AAC/N/;$codon=~s/AAA/K/;$codon=~s/AAG/K/;$codon=~s/AGT/S/;$codon=~s/AGC/S/;$codon=~s/AGA/R/;$codon=~s/AGG/R/;
    $codon=~s/GTT/V/; $codon=~s/GTC/V/;$codon=~s/GTA/V/;$codon=~s/GTG/V/;$codon=~s/GCT/A/;$codon=~s/GCC/A/;$codon=~s/GCA/A/;$codon=~s/GCG/A/;
    $codon=~s/GAT/D/; $codon=~s/GAC/D/;$codon=~s/GAA/E/;$codon=~s/GAG/E/;$codon=~s/GGT/G/;$codon=~s/GGC/G/;$codon=~s/GGA/G/;$codon=~s/GGG/G/;
    if (length($codon)==3){
        $codon='X';
    }
    return $codon;
}
