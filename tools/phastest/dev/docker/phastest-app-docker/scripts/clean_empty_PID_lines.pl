#!/usr/bin/perl -w


# clean up PID == '-' in .ptt file
#Usage: perl  clean_empty_PID_lines.pl <ptt_file> <fna_file>

if (scalar @ARGV!=3){
	print STDERR "Usage: perl  clean_empty_PID_lines.pl <ptt_file> <fna_file> <log_file>\n";
	exit(-1);
}

my $ptt_file = $ARGV[0];
my $fna_file = $ARGV[1];
my $log_file = $ARGV[2];
open(IN,$fna_file) or die "Cannot open $fna_file";
my $seq='';
while (<IN>){
	chomp($_);
	if ($_=~/^>/){
		next;
	}else{
		$seq .= $_;
	}
}
close IN;
my $leng_seq = length($seq);

open (LOG, ">>", "$log_file");
close LOG;

open (IN, $ptt_file) or die "Cannot open $ptt_file";
open (OUT, ">$ptt_file.tmp") or die "Cannot write $ptt_file.tmp";

while (<IN>){
	if ($_=~/^(\d+)\.\.(\d+)/){
		my $len = $2 -$1 +1;
		if ($len == $leng_seq){
			next;
		}
		my @a = split("\t", $_);
		if ($a[3] eq '-'){
			print $_;
			next;
		}
	}
	print OUT $_;
}
close IN;
close OUT;
system("mv -f $ptt_file.tmp $ptt_file");
exit;
