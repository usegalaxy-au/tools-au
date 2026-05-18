#!/usr/bin/perl -w

# this program will input .ppt file and region .txt file and bases on the region .txt file
# to filter the .ptt file. The output file should be the filtered info in .ppt format.
# Usage: perl region_to_ptt.pl  <.ppt file > <.txt file > <png_input> <ouput_file> 

if (@ARGV!=4){
	print "Usage : perl region_to_ptt.pl  <.ppt file > <.txt file > <png_input> <ouput_file> \n";
	exit;
}

open(IN, $ARGV[1]) or die "Cannot open $ARGV[1]";
my @array = ();
while (<IN>) {
	if ($_=~/^(\d+)\s+\d+/){
		push @array, $1;
	}
}
close IN;

my %hash =();
get_protein_name_match(\%hash, $ARGV[2]);


my $num= scalar(@array);
open (IN, $ARGV[0]) or die "Cannot open $ARGV[0]";
open (OUT, ">$ARGV[3]") or die "Cannot write $ARGV[3]";
my $end_5 ='';
my $flag =0;
while(<IN>){
	if ($_=~/^(\d+)\.\.(\d+)\s+(\S)/){
		if ($3 eq '+'){
			$end_5 = $1;
		}else{
			$end_5 = $2;
		}
		$flag =0;
		foreach my $i (0..$#array){
			if ($array[$i] == $end_5){
				$flag = 1;
				last;
			}
		}
		if ($flag ==1){
			foreach my $k (keys %hash){
				if ($_ =~/$k/){
					$_ =~s/-$/$hash{$k}/;
					last;
				}
			}
			my @a = split("\t", $_);
			if (scalar(@a) == 8) {
				$_=~s/($a[$#a])/-\t$1/;
			}
			print OUT $_;
		}			
	}else{
		if ($_=~/^\d+ proteins/){
			$_=~s/\d+ proteins/$num proteins/;
		}
		print OUT $_;
	}
}
close IN;
close OUT;
exit;

#get hash from png_input file
sub get_protein_name_match{
	my ($hash, $file)= @_;
	open(IN, $file ) or die "Cannot open $file";
	while(<IN>){
		if ($_=~/^section/){
			$_=~s/section\s+//;
			my @arr = split(/\s\s\s*/, $_);
			$$hash{"$arr[0]..$arr[1]"} = $arr[4];
		}
	}
	close IN;
}
  
	
