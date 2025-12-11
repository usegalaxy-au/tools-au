#!/usr/bin/perl -w

use Bio::Perl;
use Bio::DB::GenBank;

if (scalar @ARGV != 2){
	print "Usage: perl get_gbk.pl  <accession_number or gi number>  <tmp_dir>\n";
	exit(-1);
}

my $dir = $ARGV[1];
if ($ARGV[0]=~/^\d+$/){
	die ("GI number is no longer accepted!\n");
}

my $start = time();
my $seq;
my $tmp;
my $gb = Bio::DB::GenBank->new();

# Make sure that accession number exists.
eval {
	$seq = $gb->get_Seq_by_acc($ARGV[0]);
};

# Catch error, if there are any.
if ($@) {
	if ($ARGV[0] =~ /\_/) {
		$tmp = $ARGV[0];
		$ARGV[0]=~ s/\_//;
		($tmp, $ARGV[0]) = ($ARGV[0], $tmp);
	}
	else {
		$tmp = $ARGV[0];
		$ARGV[0]=~ s/(\d+)/\_$1/;
		($tmp, $ARGV[0]) = ($ARGV[0], $tmp);
	}
	
	$seq = $gb->get_Seq_by_acc($tmp);
}

# New .gbk file is written with name of $ARGV[0].
my $out = Bio::SeqIO->new(-file => ">$dir/$ARGV[0].gbk", -format => 'Genbank');
$out->write_seq($seq);

my $end = time() - $start;
print "Genbank file retrieved in $end seconds\n";
exit;