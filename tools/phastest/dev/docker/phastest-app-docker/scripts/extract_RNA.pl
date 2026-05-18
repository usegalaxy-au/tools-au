#!/usr/bin/perl -w 

use POSIX qw/ceil/;

# this program will extract tRNA and tmRNA info from files 
# tRNAscan.out and tmRNA_aragon.out. Also some info needed 
# from .fna and .gbk if available.
# files involved: .gbk and tRNAscan.out
# the output format will be the same as  extract_result.txt.
#Usage: perl extract_RNA.pl <case_number> <output_filename> <input type flag>
my $num = $ARGV[0];
my $output = $ARGV[1];
my $input_flag = $ARGV[2];
open(OUT, ">$output") or die "Cannot write $output";
open(IN, "$num.fna") or die "Cannot find $num.fna";
my $specie='';
my $seq ='';
while(<IN>){
	chomp($_);
	if ($_=~/^\s*>/){
		$specie = $_;
	}else{
		$seq .=$_;
	}	
}
close IN;
$seq =~s/\s//g;

my $header ="\nCDS_POSITION                       BLAST_HIT                                                                            EVALUE              prophage_PRO_SEQ\n
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------\n";
print OUT "$specie ".length($seq)."\n$header";

my %hash =();
my $flag =0;
if (-e "tRNAscan.out"){
	open(IN, "tRNAscan.out");
	while(<IN>){
		if ($_=~/^------/){
			$flag =1;
			next;
		}
		if ($flag==1){
			my @arr=split(" ", $_);
			if ($arr[2] < $arr[3]){
				$hash{$arr[2]} = "$arr[2]..$arr[3],tRNA,type:$arr[4],anti_codon:$arr[5]";
			}else{
				$hash{$arr[3]} = "complement($arr[3]..$arr[2]),tRNA,type:$arr[4],anti_codon:$arr[5]";	
			}
		}		 	
	}
	close IN;
}

if (-e "tmRNA_aragorn.out"){
	open(IN, "tmRNA_aragorn.out");
	my $flag = 0;
	my $key ='';
	while(<IN>){
		chomp($_);
		
		if ($_=~/Location \[(\d+),(\d+)\]/){
			$hash{$1} = "$1..$2";
			$key = $1;
			$flag = 0;
			next;
		}elsif($_=~/Location c\[(\d+),(\d+)\]/){
			$hash{$1} = "complement($1..$2)";
			$key = $1;
			$flag = 0;
			next;
		}
		if ($_=~/1   .   10    .   20    .   30    .   40    .   50/){
			$flag = 1;
			my $seq1 = '';
			
			next;
		}
		if ($flag ==1 && $key ne '' && $_!~/^\s*$/){
			$seq1 .= $_;
			next;
		}
		if ($flag ==1 && $_=~/^\s*$/ && $key ne ''){
			$hash{$key} .= ",tmRNA,seq:$seq1";	
			$flag =0;
			next;			
		}
		if ($_=~/Resume consensus sequence/ && $key ne ''){
			$hash{$key} .= ",$_";
			$key = '';
		}

	}
	close IN;
}

# if input is generated from gbk file, pull rRNA data from there
if ($input_flag eq "-g"){
	open(IN, "$num.gbk");
	my $flag = 0;
	while(<IN>){
		if ($_=~/^\s*rRNA\s+complement\((\d+)\.\.(\d+)\)/){
			$hash{$1} = "complement($1..$2),rRNA";
			$key = $1;
			$flag = 1;
		}elsif( $_=~/^\s*rRNA\s+(\d+)\.\.(\d+)/ ){
			$hash{$1} = "$1..$2,rRNA";
			$key = $1;
			$flag = 1;	
		}elsif($_=~/^\s+\/product=\"(.*?)\"/ && $flag ==1 && $key ne ''){
			$hash{$key} .= ",type:$1,anti_codon:";
			$key ='';
			$flag = 0;
		}
	}
	close IN;
}

# otherwise, pull rRNA from the barrnap output
else {
	open(IN, "rRNA_barrnap.out");
	while(<IN>){
		if ($_ =~ /^\>(\S+)\:\:.*\:(\d+)\-(\d+)\((\S)\)/) {
			if ($4 eq "+") {
				$hash{$2} = "$2..$3,rRNA,type:$1,anti_codon:";
			}else{
				$hash{$2} = "complement($2..$3),rRNA,type:$1,anti_codon:";	
			}
		}
	}
	close IN;
}

for (my $i = 1; $i <= ceil(length($seq)/1000000); $i++){
	my $flag = 1;
	foreach $k (sort keys %hash){
		if ($k <= $i *1000000 && $k >= ($i-1)*1000000+1){
			if ($flag ==1){
				print OUT "\n#### region $i ####\n";
				$flag = 0;
			}
			my @a = split(",", $hash{$k});
			my $seq2 = '';
			my $location = $a[0];
			if ($a[1] eq "tRNA"){
				$seq2 = get_seq(\$seq, $a[0]);
			}elsif($a[1] eq "tmRNA"){
				$seq2 = $a[2];
				$seq2 =~s/seq://;
				splice(@a,2,1);
			}else{# rRNA
				$seq2 = get_seq(\$seq, $a[0]);
			}	
			shift (@a);
			my $line = sprintf("%-35s   %-82s   %-15s   %s\n", $location, join(",", @a), "N/A", $seq2);
			print OUT $line;
		}
	}

}

close OUT;
exit;

sub  get_seq{
	my ($seq, $l )=@_;
	my $seq2 = '';
	my $start_num='';
	my $end_num = '';
	my $len='';
	if ($l =~/complement\((\d+)\.\.(\d+)\)/){
		$start_num = $1;
		$end_num = $2;		
		$len = $2-$1+1;
		$seq2 = substr($$seq, $start_num-1, $len);
		
		$seq2 =~ tr/[A,T,C,G,a,t,c,g]/[T,A,G,C,t,a,g,c]/;
		$seq2 = scalar reverse($seq2);
		
	}elsif($l =~/(\d+)\.\.(\d+)/){
		$start_num = $1;
		$end_num = $2;		
		$len = $2-$1+1;
		$seq2 = substr($$seq, $start_num-1, $len);
	}
	
	return $seq2;

}


