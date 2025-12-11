#!/usr/bin/perl -w


# this program is used to change gene code to protien sequence
# Tsage: perl change_to_protein_seq.pl <input.fna> <output_glimmer> <output.faa>

my $g_seq=`cat $ARGV[0]`;
$g_seq =~s/>.*?\n//s;
$g_seq =~s/[\s\n]//gs;
$g_seq = uc($g_seq);

open(IN, $ARGV[1]) or die "Cannot open $ARGV[1]";
open(OUT, ">$ARGV[2]") or die "Cannot write $ARGV[2]";
my $header;
my $count=0;
my $count1;
while (<IN>){
	if ($_=~/^\s*$/){
		next;
	}
	if ($_=~/^>(.*)/){
		#>gi|15638995|ref|NC_000919.1| Treponema pallidum subsp. pallidum str. Nichols, complete genome
		$header = $1;
		$header =~s/gi.*\|//;
		$header =~s/,.*//;
		next;
	}
	#orf00005   1982       1449       -3    4.21
	#orf00006   2057       2425       +2    7.47
	my @array = split (" ", $_);
	my $strand = substr($array[3], 0, 1);
	my ($start,$stop);
	my $range = '';
	if ($strand eq '+'){
		$start = $array[1]; $stop = $array[2];
		$range = "$start..$stop";
	}else{
		$start = $array[2]; $stop = $array[1];
		$range = " complement($start..$stop)";
	}
	if ($start > $stop){ #glimmer will treat genome as circulated, so when it crosses back to the start of the genome, we ignor that ORF.
		next;
	}
	my $sub_seq = substr($g_seq, $start-1, $stop-$start+1);
	if ($strand eq "-" ){
		$sub_seq = reverse($sub_seq);
		$sub_seq =~tr/[ATCG]/[TAGC]/;
	}
	
	my $pro_seq = change_to_pro_seq($sub_seq);
	# if ($pro_seq=~/NNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN/is){
	# 	# do not count in unkonwn DNA seq and proten seq.
	# 	next;
	# }
	$count++;
	$count="0$count" if (length($count)==4);
	$count="00$count" if (length($count)==3);
	$count="000$count" if (length($count) ==2);
	$count="0000$count" if (length($count) ==1);
	#>gi|26986746|ref|NP_742171.1| NONE [Pseudomonas putida KT2440     gene            complement(147..1019)]
	print OUT ">gi|$count|ref|NC_000000|  [$header	PP_$count	gene 	 $range]\n";
	
	for (my $i =0; $i < length($pro_seq)/70 +1; $i++){
		
		if ($i*70<length($pro_seq)-1){
			my $sub_str = substr($pro_seq, $i*70, 70);
			if ($sub_str ne '') {
				print OUT $sub_str."\n";
			}
		}
	}
	
}
close IN;
exit;

# change gene sequence to protein sequence
sub change_to_pro_seq{
	my $sub_seq = shift;
	my $jumps = length($sub_seq)/3;
	my $seq ;
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
