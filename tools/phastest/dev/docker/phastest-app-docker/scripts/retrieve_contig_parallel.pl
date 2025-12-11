# Author :  Scott Han
# Date :    July 28, 2022
#
# Given a .gbk file retrieved over NCBI, this code checks if that code is a master
# record for whole-genome shotgun sequences, and if so, retrieves all the contigs.
#
# Generates master record file, and .gbk of each contig on job directory.
#
# NOTE FROM EARLIER AUTHOR: 
# Due to the size of the WGS involved (42,005 is largest I've seen yet) and the fact
# that contig retrieval is bottlenecked by NCBI server's speed, retrieving entire
# contigs could be a slow process. 
# 
# Contigs of size 4000-5000 should take slightly longer than a minute to retrieve 
# completely. Contigs of size around 100-200 should take less than 10 seconds.

use threads;
use Thread::Semaphore;
use Bio::Perl;
use Bio::DB::GenBank;
use strict;
use warnings;

my @arr;
my @total_arr;
my ($header, $start, $end, $len, $first, $second);
open (FH, "<", "$ARGV[1]/$ARGV[0].gbk") || die("Cannot open contig: $!\n");
while (<FH>) {
    # WGS         ACIN03000001-ACIN03000020
    if ($_ =~ /WGS\s+(\S+)\-(\S+)/) {
        # If true, then the .gbk retrieved is a master record for WGS.
        system("mv $ARGV[0].gbk $ARGV[0]\_master_record.gbk");
        ($first, $second) = ($1, $2);
        $header = $1 if $first =~ /(\D+)/;  # ACIN ...
        $start  = $1 if $first =~ /(\d+)/;  # 03000001
        $end    = $1 if $second =~ /(\d+)/; # 03000020
        $len    = length($1);               # Length of the digits depends on record.
    }
    # WGS         ACIN03000001
    elsif ($_ =~ /WGS\s+(\D+\d+)/) {
        # Retrieve single contig and exit.
        system("mv $ARGV[0].gbk $ARGV[0]\_master_record.gbk");
        my $gb = Bio::DB::GenBank->new();
        my $seq = $gb->get_Seq_by_acc($ARGV[0]);
        my $out = Bio::SeqIO->new(-file => ">$ARGV[0].gbk", -format => 'Genbank');
        $out->write_seq($seq);
        exit;
    }
}
close FH;

# Exit if not a WGS contig.
exit if (!defined($header));

# Create contig names, push them to the array.
my $base_num = $start - 1;
my $dest_num = $end - $base_num;

for (my $id = 1; $id <= $dest_num; $id++) {
    my $acc = $id + $base_num;
    $acc = sprintf("%0*d", $len, $acc);
    push @arr, "$header"."$acc";
}

# Subdivide array into equal-sized pieces.
divide_into_subarray(200, @arr);

# Use threads to retrieve all contigs in parallel.
my $sem = Thread::Semaphore->new(2);
my @threads;
my $t = time();

foreach (@total_arr) {
    $sem->down();
    push @threads, threads->create(\&retrieve_contig, $_);
}

# Join all threads, so that it terminates properly.
foreach (@threads) {
    $_->join();
}

my $t2 = time() - $t;
print "Retrieving $dest_num contigs took $t2 seconds.\n";

# Combine all contigs into one, and delete all temporary .gbk files. Exit;
my $file_str='';
for (my $id = $start; $id <= $end; $id++){
    $id = sprintf("%0*d", $len, $id);
    my $seqname = "$header"."$id";
    $file_str .= "$seqname\.gbk_tmp ";
}
system("cat $file_str > $ARGV[0].gbk");
system("rm *_tmp");
exit;

# Divides array into maximum 200-size array.
sub divide_into_subarray {
    my $n = shift;
    while (my @next_arr = splice @_, 0, $n) {
        push @total_arr, \@next_arr;
    }
}

# Retrieve contigs en-masse. Receives reference to the array provided by @total_arr.
sub retrieve_contig {
    my $gb = Bio::DB::GenBank->new();
    my $seq = $gb->get_Stream_by_acc($_);

    while (my $clone = $seq->next_seq) {
        my $seqname = $clone->accession_number;
        my $out = Bio::SeqIO->new(-file => ">$seqname.gbk_tmp", -format => 'Genbank');
        $out->write_seq($clone);
    }
    $sem->up();
}