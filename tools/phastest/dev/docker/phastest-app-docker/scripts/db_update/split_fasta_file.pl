#!/usr/bin/perl -w

#################################################################
#
# Script to split the given FASTA file into smaller FASTA files.
# The script will take care to make splits between sequences.
#
# David Arndt, Jul 2011
#
#################################################################

use strict;

if(@ARGV<2)
{
  print "Usage: ./split_fasta_file.pl <num> <FASTA file>\n";
  print "   Splits the given FASTA file into num smaller FASTA files.\n";
  exit(0);
}

my $num_files = $ARGV[0];
my $orig_filename = $ARGV[1];

open(ORIG, "<$orig_filename");

seek(ORIG, 0, 2);
#print "EOF is at " . tell(ORIG) . "\n";
my $eof_loc = tell(ORIG);

my $line;
my $curr_part_start = 0;
my $num_skipped = 0; # Number of parts skipped.
for (my $partnum = 0; $partnum < $num_files; $partnum++) {
	
	if ($partnum == $num_files - 1) {
		
		if ($eof_loc <= $curr_part_start) {
			# The previous part included everything we would
			# want to include in the current part. This can
			# occur when there are long sequences and/or few
			# sequences in a file and a high value for $num_files.
			$num_skipped++;
		}
		else {
			# Output final part.
			my $part_label = $partnum - $num_skipped + 1;
			my $part_filename = "$orig_filename\.part$part_label";
			open (PART, ">$part_filename");
			seek(ORIG, $curr_part_start, 0);
			while (<ORIG>) {
				$line = $_;
				print(PART $line);
			}
			close(PART);
		}
	}
	else {
		seek(ORIG, $eof_loc*(($partnum + 1)/$num_files), 0);
		
		$line = <ORIG>; # Read the remainder of the line.
		my $prev_loc = tell(ORIG);
		
		while (<ORIG>) {
			my $line = $_;
			if ($line =~ /^>/) {
				last;
			}
			else {
				$prev_loc = tell(ORIG);
			}
		}
		
		my $next_part_start = $prev_loc;
		
		if ($next_part_start <= $curr_part_start) {
			# The previous part included everything we would
			# want to include in the current part. This can
			# occur when there are long sequences and/or few
			# sequences in a file and a high value for $num_files.
			$num_skipped++;
		}
		else {
			# Output current part, up to $next_part_start
			my $part_label = $partnum - $num_skipped + 1;
			my $part_filename = "$orig_filename\.part$part_label";
			open (PART, ">$part_filename");
			seek(ORIG, $curr_part_start, 0);
			while (<ORIG>) {
				$line = $_;
				print(PART $line);
				if (tell(ORIG) >= $next_part_start) {
					last;
				}
			}
			close(PART);
		}
		
		$curr_part_start = $next_part_start;
		
	}
	
}

my $num_parts = $num_files - $num_skipped; # Actual number of parts created.
if ($num_skipped > 0) {
	print(STDERR "Only $num_parts parts created ($num_skipped would have been empty).\n");
}


# Output shell scripts for BLAST commands
# for (my $partnum = 0; $partnum < $num_parts; $partnum++) {
# 	my $part_filename = "$orig_filename\.$partnum";
# 	my $script_filename = "$orig_filename\.$partnum\.sh";
# 	
# 	open(OUT, ">$script_filename");
# 	print(OUT "");
# 	
# 	
# 	close(OUT);
# }

close(ORIG);