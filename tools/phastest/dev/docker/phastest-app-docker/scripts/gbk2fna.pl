#!/usr/bin/perl

if (@ARGV!=1){
	print STDERR "Usage : perl gbk2fna.pl <gbk_file>\n";
	exit(-1);
}
my $input=$ARGV[0];
my $output=$input;
$output =~s/\.gbk//;
$output .=".fna";
gbk2fna($input,$output);
if (-s $output){
	print "$output created!\n";
}else{
	print "That is weird, NO $output created!\n";
}
exit;
	
sub gbk2fna{
	my ($input,$output)=@_;
	
	my @GenBankFile = (  );
	my $o=''; #organism
	my $d=''; #total sequence
	my $d1=''; #version+accession
	my $d4=''; #nucleic acid sequence
	my $d4t=''; #temp of d4
	my $true=0;
	my $GI = '00000000';
	my $acc = 'NC_000000';
	@GenBankFile=get_file_data($input);
    
	foreach my $line (@GenBankFile) {
		if ($line=~/^\s*$/){
			next;
		}
		if($line=~/^\/\/\n/){
			$true=0; # Will execute once and exit loop, unless .gbk is generated from contig.
		}
		elsif($line=~/^DEFINITION/){
			$line=~s/^DEFINITION (.+?)\n/$1/g;
			$o=$line;
			$o=~s/\n//;
		}
		elsif($line=~/^VERSION/){
			if($line=~/^VERSION\s+(\S+)\s+GI:(\d+)/){
				$GI = $2;
				$acc = $1;
			}
			$d1=$line;
			chop($d1);
        	}
	        elsif($line=~/^ORIGIN/){
        		$true=1;
        	}	
	        elsif($true==1){
        		$d4t.=$line;
        	}
    	}
    
    $d4t=~s/[\s0-9]//g;
	$d4=uc($d4t);
	$d=">gi|$GI|ref|$acc| ".$o."\n";
	
	my $i=0;
	while($i<length($d4)) {
		$d.=substr($d4,$i,70)."\n";
		$i+=70;
	}

    open(FNA,">$output");
	print FNA $d;
	close FNA;
	return 1;
    
}

sub get_file_data{
	
	my ($file)=@_;
	use strict;
	use warnings;

	# Initialize variables
	my @filedata=();
	unless(open(GET_FILE_DATA,$file)) {
		print STDERR "Cannot open file \"$file\"\n\n";
		exit;
	}
	@filedata=<GET_FILE_DATA>;
	close GET_FILE_DATA;
	return @filedata;
}

