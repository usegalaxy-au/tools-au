# Author :  Scott Han
# Date :    July 28, 2022
#
# Parse and process contig position for the .gbk file derived from WGS sequences.
#
# Produces .txt file containing contig's start/end location and its length.

use strict;
use warnings;

my $num = $ARGV[0];
my $length = 0;
my $last_length = 1;

my $gbk = `cat $num\.gbk`;
my @lines = split("\n", $gbk);
my @results;

foreach (@lines) {
    if ($_ =~ /\s+(\d+) bp/) {
        $length += $1;
        push @results, "$last_length-$length-$1";
        $last_length = $length + 1;
    }
}

open(FH, ">", "$num\_contig_positions.txt") || die("Cannot create contig files: $!\n");
my $contig_count = 0;
foreach (@results) {
    $contig_count++;
    my @arr = split("-", $_);
    
    # Keep format same as .fna based contig files.
    if ($contig_count > 1) {
        my $original_pos = $arr[0] - 1;
        print FH "contig,$contig_count,at,$original_pos\t$arr[0]\t$arr[1]\t$arr[2]\n";
    }
    else {
        print FH "contig,$contig_count\t$arr[0]\t$arr[1]\t$arr[2]\n";
    }
}
close FH;
exit;