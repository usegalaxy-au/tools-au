#!/usr/bin/perl

# this program is used to generate contig 
# positions for contig fna file.
# Usage: perl make_contig_position.pl <original fna file>

open(IN, $ARGV[0]) or die "cannot open $ARGV[0]!";
my ($out_file) = $ARGV[0]=~/(.*?)_original.fna/;
$out_file .= "_contig_positions.txt";
open(OUT, "> $out_file") or die "Cannot write $out_file!";

my $contig_seq = "";
my $contig_info = "";
my $contig_pos = 0 ;
my $first_line = 1;

while(my $line=<IN>){
    if ($line =~ /^>/){
        chomp($line);
        $line =~s/>//g;
        $line =~s/\s+/,/g;

        if ($contig_seq ne ''){
          if ($first_line==1){
            $contig_info .= "1\t";
            $first_line = 0;
            $contig_pos += length($contig_seq);
          }else{
            $contig_info .= "$contig_pos\t";
            $contig_pos += length($contig_seq) - 1;
          }

          $contig_info .= "$contig_pos\t";
          $contig_info .= length($contig_seq);
          print OUT "$contig_info\n";
          $contig_pos += 1;
        }
        $contig_seq = "";
        $contig_info = "$line\t";
        
    }else{
        chomp($line);
        $contig_seq .= $line;
    }
        
}
if ($contig_seq ne ''){
    if ($first_line==1){
        $contig_info .= "1\t";
        $first_line = 0;
        $contig_pos += length($contig_seq);
    }else{
        $contig_info .= "$contig_pos\t";
        $contig_pos += length($contig_seq) - 1;
    }

    $contig_info .= "$contig_pos\t";
    $contig_info .= length($contig_seq);
    print "$contig_info\n";
    print OUT "$contig_info\n";
    $contig_pos += 1;
}

close IN;
close OUT;
print "$out_file generated!\n";
exit;