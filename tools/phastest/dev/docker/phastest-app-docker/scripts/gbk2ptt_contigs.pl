#!/usr/bin/perl -w

# Author :  Scott Han
# Date :    July 28, 2022
#
# Similar to gbk2ptt.pl, but this code is adapted specifically to handle WGS records.
# Generates .ptt sequence of the entire WGS sequence, treating combination of all
# contigs as a one massive genbank record. 
#
# Output is sent to the STDOUT; PHASTER/PHASTEST outputs it to .ptt file.
#
# Usage: perl gbk2ptt_contigs.pl <.gbk file> <contig positions.txt>

use strict;
use Bio::SeqIO;
use Bio::Perl;
use Cwd;

my $filename = $ARGV[0];
my $contig_loc = $ARGV[1];
my ($header, $start, $end, $len);

# Add information to the contig positions output.
my $gbk = `cat $filename`;
my @lines = split("\n", $gbk);
my $line = '';
my $flag = 0;
my @draft;

foreach (@lines) {
   if ($_ =~ /^ACCESSION/) {
      push @draft, $_;
      $flag = 0;
   }
   elsif ($_ =~ /^\s+CDS\s+(join|\<|\d|complement)/ && !$flag) {
      $flag = 1;
   }
   elsif ($_ =~ /^\s+CDS\s+(join|\<|\d|complement)/ && $flag) {
      push @draft, $line if $line ne "";
      $line = "";
   }
   elsif ($_ =~ /^\s+gene\s+(join|\<|\d|complement)/ && $flag) {
      $flag = 0;
      push @draft, $line if $line ne "";
      $line = "";
   }
   elsif ($_ =~ /^ORIGIN/ && $flag) {
      $flag = 0;
      push @draft, $line if $line ne "";
      $line = "";
   }
   # If flag == 1, grab everything between "CDS" header and "gene" header.
   if ($flag) {
      $line .= $_;
   }
}

print join("\t", qw(Location Strand Length PID Gene Synonym Tag COG GO_Component GO_Function GO_Process Notes Product)),"\n";

# Find each header, and process them.
my ($protein_id, $product, $locus_tag, $location, $gene, $strand, $length, $curr_loc, $curr_end);
my ($GO_proc, $GO_comp, $GO_func, $notes);
my $gi_count = 0;
my $region_count = 0;

@lines = split("\n", `cat $contig_loc`);

foreach my $rec (@draft) {
   $protein_id='NONE';
   $product='NONE';
   $locus_tag='NONE';
   $location ='NONE';
   $gene ='-';
   $strand = '+';
   $length = 0;
   my ($l, $r) = (0, 0);
   $GO_proc = "NONE";
   $GO_comp = "NONE";
   $GO_func = "NONE";
   $notes = "N/A";

   if ($rec =~ /^ACCESSION/) {
      $curr_loc = $1 if $lines[$region_count] =~ /^\S+\s+(\d+)\s/;
      $curr_end = $1 if $lines[$region_count] =~ /(\d+)\s+\d+$/;
      $region_count++;
      next;
   }
   if ($rec=~/^\s+(CDS)\s+(.*?)\s+/s ) {
      $location = $2;
      $location =~s/\n//g;
      $location =~s/\s//g;
      $location =~s/>//g;
      $location =~s/<//g;
      $location =~s/join\((\d+)(?:\,|\.).*(?:\,|\.)(\d+)(?:\)|\,)/$1\.\.$2/g;
      ($l, $r) = ($1, $2) if $location =~ /(\d+)\.\.(\d+)/;
      $location =~ s/\((\d+\.\.\d+)$/\($1\)/g;
      $location =~ s/complement\((.*?)\)/$1/g;
      $length = $r - $l;
   }
   if ($rec=~/CDS\s+complement/) {
      $strand = '-';
   }
   if($rec=~/\/product\=\"(.*?)\"/) {
      $product=$1;
      $product=~s/\n\s+/ /gs;
      $product=~s/[ \t]{2,}/ /gs;
   }
   if ($rec=~/\/locus_tag\=\"(.*?)\"/) {
      $locus_tag = $1;
   }
   if ($rec=~/\/gene\=\"(.*?)\"/) {
      $gene = $1;
   }
   if ($rec=~/\/protein_id\=\"(.*?)\"/) {
      $protein_id = $1;
   }
   if ($rec=~/\/GO_function\=\"(.*?)\"/) {
      $GO_func = $1."\;";
      $GO_func =~ s/\s+/ /g;
   }
   if ($rec=~/\/GO_component\=\"(.*?)\"/) {
      $GO_comp = $1."\;";
      $GO_comp =~ s/\s+/ /g;
   }
   if ($rec=~/\/GO_process\=\"(.*?)\"/) {
      $GO_proc = $1."\;";
      $GO_proc =~ s/\s+/ /g;
   }
   if ($rec=~/\/note\=\"(.*?)\"/) {
      $notes = $1;
      $notes =~ s/\s+/ /g;
   }
   if ($length <= 0) {
      print STDERR "Negative or zero length CDS in $location - skipped.\n";
      next;
   }
   $l += $curr_loc - 1;
   $r += $curr_loc - 1;

   $gi_count++;
   $gi_count="0$gi_count" if (length($gi_count) == 4);
   $gi_count="00$gi_count" if (length($gi_count) == 3);
   $gi_count="000$gi_count" if (length($gi_count) == 2);
   $gi_count="0000$gi_count" if (length($gi_count) == 1);

   my $cog = '-';
   $cog = $1 if $product =~ m/^(COG\S+)/;

   my $acc = '-';
   $acc = $1 if $protein_id =~ m/^(.*)/;
   $acc = "[$acc]" if $acc ne "NONE";
   $acc = " " if $acc eq "NONE";

   if ($r <= $curr_end){
      my @col = (
         "$l\.\.$r",
         $strand,
         int ($length/3),
         $gi_count,
         $gene,
         "PP_"."$gi_count",
         $locus_tag,
         $cog,
         $GO_comp,
         $GO_func,
         $GO_proc,
         "\"$notes\"",
         $product . " $acc",
      );
      print join("\t", @col), "\n";
   }
}

exit;
