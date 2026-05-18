#!/usr/bin/perl -w

# Script to call FragGeneScan in parallel, submitting the parts of the task to multiple
# cluster nodes.

use File::Basename;

our $MAX_PIECES = 100; # control splitting files maxium to 100 pieces
my $t1= time;

my $scripts_dir = "$ENV{PHASTEST_HOME}/scripts";
my $sub_programs_dir = "$ENV{PHASTEST_HOME}/sub_programs";

my $num = $ARGV[0];
my $fna_file = $ARGV[1];
my $contig_pos = $ARGV[2];
my $log_file = $ARGV[3];
my $dir = dirname($fna_file);

# Modify _filtered.fna to include the start and end position of each contig
create_filtered_fna($fna_file, $contig_pos);

# Run FragGeneScan on the filtered fna file
if ( ! -e "$dir/$num.predict" ) {
	my $fna_file_basename = "$num\_filtered.fna";
	my $fraggenescan_exec = "$sub_programs_dir/FragGeneScan1.20/run_FragGeneScan.pl";
	my $cmd = "$scripts_dir/run_fraggenescan.sh $fna_file_basename $fraggenescan_exec $contig_pos $log_file";
	system("$cmd");

	open(OUT, ">$num.predict") or die "Cannot write $num.predict";
	print OUT ">gi|000000|ref|NC_000000|  Concatenated genome\n";

	my $orf_count = 0;
	my $start_num = 0;
	open(IN, "$fna_file_basename.out") or die "Cannot open $fna_file_basename.out";
	while (my $l = <IN>){
		if ($l=~/^>/){
			if($l=~ m/ (\d+)\-\d+$/){
				$start_num = $1;
			}
			next;	
		}else{
			if ($start_num == 0) {
				die "Format in $fna_file_basename.out not correct on line $l\n";
			}

			my @arr=split(" ", $l);
			$arr[0] += $start_num-1;
			$arr[1] += $start_num-1;
			$orf_count++; 
			my $orf_str='';
			if ($orf_count >0 && $orf_count<10) {
				$orf_str='0000'.$orf_count;
			}elsif($orf_count >=10 && $orf_count<100) {
				$orf_str='000'.$orf_count;
			}elsif($orf_count >=100 && $orf_count<1000) {
				$orf_str='00'.$orf_count;
			}elsif($orf_count >=1000 && $orf_count<10000) {
				$orf_str='0'.$orf_count;
			}else{
				$orf_str=$orf_count;
			}
			my $line = '';
			($arr[0], $arr[1], $arr[2]) = check_length($arr[0], $arr[1], $arr[2]);
			if ($arr[2]=~/\+/) {
				$line = sprintf("%-10s %-10s %-10s %-5s %-20s\n", "orf$orf_str", $arr[0], $arr[1], "$arr[2]$arr[3]", $arr[4]);
			}elsif ($arr[2]=~/\-/){
				$line = sprintf("%-10s %-10s %-10s %-5s %-20s\n", "orf$orf_str", $arr[1], $arr[0], "$arr[2]$arr[3]", $arr[4]);
			}else{
				die "Format in $fna_file_basename.out not correct on line $l\n";
			}
			print OUT $line;	
		}
	}
	close IN;
	close OUT;

	# Delete temp file - they'll have extensions like {num}_filtered.fna.faa/.ffn/.out
	system("rm $num\_filtered.fna.*");
}
exit;

# Creates a new fna file with the start and end position of each contig
sub create_filtered_fna {
	my ($fna_file, $contig_pos) = @_;
	my $contig_num = 0;

	my $contig_pos_file = `cat $contig_pos`;
	my @lines = split("\n", $contig_pos_file);

	open (IN, "<$fna_file") or die "Cannot read $fna_file";
	open (OUT, ">$dir/$num\_filtered.fna") or die "Cannot write $dir/$num\_filtered.fna";
	while (<IN>) {
		chomp ($_);
		if ($_ =~ /^>/) {
			my $contig_start = 0;
			my $contig_end = 0;

			if ($lines[$contig_num] =~ /(\d+)\s+(\d+)\s+\d+$/) {
				$contig_start = $1;
				$contig_end = $2;
			}

			print OUT "$_ $contig_start-$contig_end\n";
			$contig_num++;
		}
		else {
			print OUT "$_\n";
		}

		if ($contig_num > scalar(@lines)) {
			die "Number of contigs in $fna_file does not match number of contigs in $contig_pos";
		}
	}
	close IN;
	close OUT;
}

# Check the length of the sequence and make sure it is a multiple of 3
sub check_length{
	my ($start, $end, $forward_or_backward) = @_;
	my $rest = ($end - $start + 1) % 3;
	if ($forward_or_backward =~ m/\+/){
		if ($rest != 0){
			$start += $rest;
		}
	}elsif($forward_or_backward =~ m/\-/){
		if ($rest != 0){
			$end -= $rest;
		}
	}
	else{
		die "forward_or_backward not clear in line with $start and $end";
	}
	return $start, $end, $forward_or_backward;
}