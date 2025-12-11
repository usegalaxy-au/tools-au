#!/usr/bin/perl -w
use strict;
# This script takes a GenBank file as input, and produces a
# NCBI PTT file (protein table) as output. A PTT file is
# a line based, tab separated format with fixed column types.
#
# Written by Torsten Seemann
# 18 September 2006
#
# Modified by Scott Han
# 10 August 2022
#
# Usage: perl gbk2ptt.pl <gbk_file>
# output from standardout

my $gbk_file = $ARGV[0];

# These entries are present only for some gbk files.
my $GO_process_flag     = 0;
my $GO_function_flag    = 0;
my $GO_component_flag   = 0;

my $gbk = `cat $gbk_file`;
my @lines = split("\n", $gbk);
my $flag = 0;
my $line = "";
my @draft;	# Each element of this array consists of CDS.

foreach(@lines){ 
   if ($_ =~ /^\s+CDS\s+(join|\<|\d|complement)/ && !$flag) {
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
   if ($_ =~ /\/GO_component\=/) {
      $GO_component_flag = 1;
   }
   if ($_ =~ /\/GO_function\=/) {
      $GO_function_flag = 1;
   }
   if ($_ =~ /\/GO_process\=/) {
      $GO_process_flag = 1;
   }
}

print join("\t", qw(Location Strand Length PID Gene Synonym Tag COG GO_Component GO_Function GO_Process Notes Product)),"\n";

my ($protein_id, $product, $locus_tag, $location, $gene, $strand, $length);
my ($GO_proc, $GO_comp, $GO_func, $notes);
my $gi_count = 0;

# Single line of $rec consists of entire CDS and its data.
foreach my $rec (@draft) {
   $protein_id='NONE';
   $product='NONE';
   $locus_tag='NONE';
   $location ='NONE';
   $gene ='-';
   $strand = '+';
   $length = 0;
   $GO_proc = "NONE";
   $GO_comp = "NONE";
   $GO_func = "NONE";
   $notes = "N/A";

   if ($rec=~/^\s+(CDS)\s+(.*?)\s+/s ) {
      $location = $2;
      $location =~s/\n//g;
      $location =~s/\s//g;
      $location =~s/>//g;
      $location =~s/<//g;
      $location =~s/join\((\d+)(?:\,|\.).*(?:\,|\.)(\d+)(?:\)|\,)/$1\.\.$2/g;
      my ($l, $r) = ($1, $2) if $location =~ /(\d+)\.\.(\d+)/;
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
   if ($rec=~/\/inference\=\"(.*?)\"/) {

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

   $gi_count++;
   $gi_count="0$gi_count" if (length($gi_count) == 4);
   $gi_count="00$gi_count" if (length($gi_count) == 3);
   $gi_count="000$gi_count" if (length($gi_count) == 2);
   $gi_count="0000$gi_count" if (length($gi_count) == 1);

   my $cog = '-';
   $cog = $1 if $product =~ m/^(COG\S+)/;

   my $acc = '-';
   $acc = $1 if $protein_id =~ m/^(.*)/;
   $acc = "[$acc]";

   $product = "Possible pseudogene" if $product eq 'NONE';

   my @col = (
      $location,
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