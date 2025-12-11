#!/usr/bin/perl -w

use strict;
use  Cwd;
use File::Copy;
use File::Path;

my $exec_dir = "/home/prion/phastest-app/scripts/db_update";
my $tmp_dir = "/home/prion/phastest-app/DB/temp_bac_select";

if (!-d $tmp_dir){
	print "There is no $tmp_dir, program exit!\n";
	exit(-1);
}
chdir $tmp_dir;

my $start_time = time;
print  `date`;
system("rm -rf *") if (-e "list");

#Generate faa files for refseq representative assemblies
my $ret = system("perl $exec_dir/parse_bac_assembly.pl");
if ($ret != 0) {
	if ($ret == -1) {
		print STDERR "parse_bac_assembly.pl failed to run\n";
		exit(7);
	} else {
		my $exitcode = $ret >> 8;
		print STDERR "parse_bac_assembly.pl failed with exit status $exitcode\n";
		exit(8);
	}
}

my $cmd=q{wget --input protein_file};
system $cmd;
$cmd=q{gunzip *.faa.gz};
system $cmd;

system("ls >list");

open(IN, "list") or die "Cannot open list";
my $output="bacteria_all_select_unfiltered.db";
unlink ($output);
open(OUT, ">$output") or die "Cannot write $output";
my $count=0;
while(<IN>) {
	chomp ($_);
	
	if ($_ eq 'list' or $_ eq 'assembly_summary.txt' or $_ eq 'protein_file' or  $_ =~/bacteria_all_select_unfiltered\.db/  ){
		next;
	}
	
	my $file = $_;
	$count++;
	my $data = `cat $file`;
	print OUT $data;
	
}
close IN;
close OUT;
print "In list, we found $count bacteria organisms!\n";

open(IN, "bacteria_all_select_unfiltered.db") or die "Cannot open bacteria_all_select_unfiltered.db";
open(OUT, ">bacteria_all_select_unfiltered.db.tmp") or die "Cannot write bacteria_all_select_unfiltered.db.tmp"; 

my %hash =();
my $flag = 0;
while(<IN>) {
	if ($_=~/>gi\|(\d+)/){
		#>gi|158333234|ref|YP_001514406.1| NUDIX hydrolase [Aca
		$hash{$1} += 1;
		if ($hash{$1}>1){
			$flag = 1;
		}else{
			$flag =0;
			print OUT $_;
		}
	}else{
		if ($flag==0){
			print OUT $_;
		}
	}
}
close IN;
close OUT;
system("mv -f bacteria_all_select_unfiltered.db  bacteria_all_select_unfiltered.db.previous");
system("mv -f bacteria_all_select_unfiltered.db.tmp  bacteria_all_select_unfiltered.db");

my $error_flag = 0;
if (-s "bacteria_all_select_unfiltered.db"){
# 	system("echo 'make bacteria_all_select_header_lines.db'");
# 	system("grep '>' bacteria_all_select.db > bacteria_all_select_header_lines.db");

	#TODO - uncomment when will replace the current database
	# system(" /home/prion/blast/bin/formatdb  -i  bacteria_all_select.db -o T ");
	#print "Copy bacteria_all_select* to upper level\n";
	#system("cp bacteria_all_select* ../.");
	
	#clean up
	system("rm -f *.faa") if (-s 'list');
}else{
	print "bacteria_all_select_unfiltered.db  has no content. Please check!\n";
	$error_flag = 1;
}
my $end_time = time;
my $time = $end_time - $start_time;
my $min = int($time /60);
my $sec = $time % 60;
print "running time = $min min $sec sec\n";
print "Program exit!\n\n\n";
if ($error_flag ==1){
	exit(-1);
}
exit;


