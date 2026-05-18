#!/usr/bin/perl -w

# this program will change glimmer result file into .ptt format for input of phage finder
# Usage: perl  change_to_ptt_format.pl <input_file.fna> <output_of_glimmer> < <output_file.ptt>  

#get the length of entire sequence
my $data = `cat $ARGV[0]`;
$data =~s/>.*?\n//s;
$protein_num = `cat $ARGV[1] |wc -l`;
$protein_num =~s/\n//;
$protein_num -=1; # not count in the header line
$data =~s/[\s\n]//sg;
my $length = length($data);

open (IN, $ARGV[1]) or die "Cannot open $ARGV[1]";
open (OUT, "> $ARGV[2]") or die "Cannot write  $ARGV[2]";
my $header;
my @array=();
my $count=0;
my $count1;
while(<IN>){
	if ($_=~/^\s*$/){
		next;
	}
	if ($_=~/^>(.*)/){
		$header = $1;
		print OUT $header.". - 0..$length\n";
		print OUT "$protein_num proteins\n";
		print OUT join("\t", qw(Location Strand Length PID Gene Synonym Tag COG GO_Component GO_Function GO_Process Notes Product)),"\n";
		next;
	}		
	@array=split(" ", $_);
	my $strand = substr($array[3], 0, 1);
	my $pro_seq_len;
	my $range;
	if ($strand eq '+'){
		$pro_seq_len = ($array[2]-$array[1]+1)/3 -1; # do not need the last stop codon
		$range ="$array[1]..$array[2]";
	}else{
		$pro_seq_len = ($array[1]-$array[2]+1)/3 -1; # do not need the last stop codon
		$range ="$array[2]..$array[1]";
	}
	$count++;
	if (length($count)==4){
		$count1="0$count";
	}elsif (length($count)==3){
		$count1="00$count";
	}elsif(length($count) ==2){
		$count1="000$count";
	}elsif (length($count) ==1){
		$count1="0000$count";
	}else{
		$count1=$count;
	}
	print OUT "$range\t$strand\t$pro_seq_len\t$count1\t-\tPP_$count1\t-\t-\tNONE\tNONE\tNONE\t\"Predicted gene region.\"\t\-\n";
}
close IN;
close OUT;
exit;
