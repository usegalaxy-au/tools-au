#!/usr/bin/perl -w

##########################################################################################
#
# Script for updating the virus database part named virus.db (the most important part) and
# the vgenome.tbl file (used by scan.pl). The final viral database (prophage_virus.db) is
# a combination of virus.db and prophage.db as combined by the make_prophage_virus_db.pl
# script. This script only generates virus_updated.db and vgenome_updated.tbl in $tmp_dir
# and does not overwrite the database files currently in use.
#
# Directory structure assumptions:
#   - The existing main virus.db and vgenome.tbl files are one level above $tmp_dir.
# 
# What the script does:
#		- For virus.db:
#     - Finds Bacterial and Archael viruses and phage from NCBI that are not present in
#       the existing database (../virus.db).
#     - For each new viral genome, obtains the GenBank files, derives each viral gene from
#       this, and adds the viral gene sequences to the virus_additions.db database file in
#       $tmp_dir.
#     - Creates combines the existing ../virus.db file and virus_additions.db to create
#       virus_updated.db in $tmp_dir.
#   - For vgenome.tbl
#     - For the new viral genomes above, generates a vgenome_additions.tbl file in
#       $tmp_dir. The format is tab-delimited with the first 4 columns having the
#       genome accession number, species, genome length, and number of genes. The rest of
#       the columns consist of gi numbers for each genes in the viral genome.
#     - Creates combines the existing ../vgenome.tbl file and vgenome_additions.tbl to
#       create vgenome_updated.tbl in $tmp_dir.
#
##########################################################################################

use strict;
use  Cwd;
use  File::Copy;

if ( !defined( $ENV{PHASTEST_CLUSTER_HOME} ) ) {
    die 'The PHASTEST_CLUSTER_HOME enviroment variable is not set\n';
}
my $CLUSTER_HOME = $ENV{PHASTEST_CLUSTER_HOME};

my $exec_dir = "$CLUSTER_HOME/scripts";
my $tmp_dir = "$CLUSTER_HOME/DB/temp_vir";

if (!-d $tmp_dir){
	print "There is no $tmp_dir, program exit!\n";
	exit(-1);
}


my $start_time = time;
chdir $tmp_dir;
# system("rm -rf *") if (-e "list");


system("wget -O phage_bacteria.html 'http://www.ncbi.nlm.nih.gov/genomes/GenomesGroup.cgi?taxid=10239&host=bacteria' 2>&1 |cat >/dev/null");
system("wget -O phage_archaea.html 'http://www.ncbi.nlm.nih.gov/genomes/GenomesGroup.cgi?taxid=10239&host=archaea' 2>&1 |cat >/dev/null");

if (-e "phage_bacteria.html"){
	print "phage_bacteria.html is generated!\n";
}else{
	print "No phage_bacteria.html is generated!\n";
	exit(-1);
}

if (!(-s "phage_bacteria.html")){
	print "Something wrong when wget -O phage_bacteria.html 'http://www.ncbi.nlm.nih.gov/genomes/GenomesGroup.cgi?opt=virus&taxid=10239&host=bacteria'\n";
	exit(-1);
}

if (-e "phage_archaea.html"){
	print "phage_archaea.html is generated!\n";
}else{
	print "No phage_archaea.html is generated!\n";
	exit(-1);
}

if (!(-s "phage_archaea.html")){
	print "Something wrong when wget -O phage_archaea.html 'http://www.ncbi.nlm.nih.gov/genomes/GenomesGroup.cgi?opt=virus&taxid=10239&host=archaea'\n";
	exit(-1);
}

my $need_phage = `cat phage_bacteria.html` . `cat phage_archaea.html`;
print $need_phage;
my @need_arr = $need_phage =~/>(NC_\d+)</gs;

print "Total phage organisms in NCBI list (including ones we have already) =".scalar(@need_arr)."\n";
my %hash_old_virus = get_hash_old_virus_db();
print "Already have ".scalar(keys %hash_old_virus)." NC in local virus.db\n";

my $output="virus_additions.db";
unlink ($output);
open(OUT, ">$output") or die "Cannot write $output";
my $last ='';
my $curr_dir =getcwd;
my $count=0;

#now handle the not intercepted NC in phage.html
my @old_keys = keys %hash_old_virus;
@need_arr = minus(\@need_arr, \@old_keys);
print "The rest virus genome count = ". (scalar @need_arr)." from phage.html\n";
# handle extra genomes
foreach my $s (@need_arr){
		#print "   $s from need_arr not found in curr_arr, call genbank to get the gbk file!\n";
		foreach (1..4){
    	system("perl $exec_dir/get_gbk.pl  $s  $tmp_dir");# create .gbk file
			last if (-s "$tmp_dir/$s.gbk");
		}

		# Create empty .faa file if it does not exist.
		if (!-f "$s.faa") {
			open my $fh, '>>', "$s.faa";
			close $fh;
		}

    system("perl $exec_dir/gbk2faa.pl $tmp_dir/$s.gbk $tmp_dir/$s.faa"); #create .faa file
		if (-s "$tmp_dir/$s.gbk"){
			print "  $s.gbk back from genbank\n";
		}else{
		  print "  No $s.gbk back from GENbank\n";
		}
    my $data = `cat $s.faa`;
    $data =~s/,\s*complement\(\d+\.\.\d+\)//gs;
    $data =~s/,\s*\d+\.\.\d+//gs;
    my @lines =split("\n", $data);
    foreach my $l (@lines){
      if ($l =~/>gi.*\[(\S+).*\s+(\S+)\]/ or $l =~/>gi.*\[(\S+)\]/){
      	my $substr='';
     		if (defined $2 ){
        	$substr= "PHAGE_".substr($1,0,6)."_$2";
	      }else{
  	      $substr= "PHAGE_".substr($1,0,6);
    	  }
      	 $substr=~s/[\s-]/_/g;
	      $l =~s/>gi/>$substr\_$s-gi/;
	  	}
	   print OUT $l."\n";
		}
		unlink "$tmp_dir/$s.gbk", "$tmp_dir/$s.faa";
}
close OUT;
my $error_flag = 0;
if (-s "virus_additions.db"){
	print "append new sequences to main database\n";
	system("cp ../virus.db virus_updated.db");
	system("cat virus_additions.db >> virus_updated.db");
}else{
	print "virus_additions.db  has no content. Please check!\n";
	$error_flag = 1;
}

# handle vgenome.tbl file for scan.pl to use
my @curr_arr=();
push @curr_arr,@need_arr; 
@curr_arr = uniq(@curr_arr) if (scalar @curr_arr !=0);
make_vgenome_file(@curr_arr);

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

sub make_vgenome_file{
	my @array = @_;
	    #check if different with the old phage list file
			my $data = `cat ../vgenome.tbl`;
			my @arr2 = (); # Array of accession numbers in vgenome.tbl
			foreach my $l (split("\n", $data)){
				my @tmp = split("\t", $l);
				push @arr2, $tmp[0];
			}
			my @rest = minus(\@array, \@arr2); # Array of new accession numbers
			if (scalar @rest ==0){
			   print "XXXXX There is no extra new virus entry from NCBI\n\n";
				 print "exit make vgenome file\n";
				 return;
			}else{
			   print "XXXXX There are ".(scalar @rest)." new virus entries from NCBI.\n\n";
			}
			open (OUT, ">vgenome_additions.tbl") or die "Cannot open vgenome_additions.tbl";
			my $c =0;
			foreach my $NC (@rest){
			  $c++;
			  print "\tWorking on $NC, count $c\n";
			  system("perl $exec_dir/get_gbk.pl  $NC  $tmp_dir");# create .gbk file

			  if (!-f "$NC.faa") {
				open my $fh, '>>', "$NC.faa";
				close $fh;
			}

			  system("perl $exec_dir/gbk2faa.pl $tmp_dir/$NC.gbk $tmp_dir/$NC.faa"); #create .faa file
			  my $data = `cat $NC.gbk`;
			  my $length = '';
			  my $sp = '';
			  if ($data =~/LOCUS\s+\S+\s+(\d+)\s+bp.*?\nSOURCE\s+(.*?)\n/s){
			    $length=$1;
			    $sp = $2;
			    $sp =~s/\(.*\)//;
			  }
			  my $str ='';
			  my $count=0;
		    open (IN, "$NC.faa") or die "Cannot open $NC.faa";
		    while (my $l = <IN>){
		     if ($l=~/>gi\|(\d+)\|/){
		       $str .= "\t$1";
		       $count++;
			   }
		    }
		    close IN;
		    if ($count !=0){
		      print OUT "$NC\t$sp\t$length\t$count$str\n";
					print "          add $NC to vgenome_additions.tbl\n";
	     	}else{
					print "          NO add $NC to vgenome_additions.tbl, there is no #gi\n";
				}
		    unlink "$tmp_dir/$NC.gbk", "$tmp_dir/$NC.faa";
		  }
		close OUT;
		print "Create vgenome_updated.tbl\n";
		system("cp ../vgenome.tbl vgenome_updated.tbl");
		system("cat vgenome_additions.tbl >> vgenome_updated.tbl");
		print "XXXX vgenome_updated.tbl generated!\n";
}

sub get_prefix{
	my $v_name= shift;
	$v_name =~s/_phage//;
	$v_name =~s/Phage_//;	
	if ($v_name =~/^([A-Za-z]+)_/){
		my $str = $1;
		my $str_sub = substr($str, 0, 6);
		$v_name =~s/^([A-Za-z]+)_/$str_sub\_/;
	}else{
		#print "Wierd, $v_name\n";
	}
	$v_name = "PHAGE_$v_name";
	return $v_name;

}
sub uniq {
		my @a = @_;
		my @tmp=();
		my %hash=();
		foreach (@a){
		  next if (! defined $_ || $_ =~/^\s*$/);
			$hash{$_}=1;
		}
		@tmp = keys %hash;
		#@tmp = keys %{{ map { $_ => 1 } @a }} ;
		return @tmp;
}

# Given two sets (as arrays), return items in the first set not present in the second.
sub minus{
 my $arr1= shift;
 my $arr2=shift;
 my @arr1 = (); @arr1 = uniq(@$arr1) if (scalar @$arr1 !=0);
 my @arr2 = (); @arr2 = uniq(@$arr2) if (scalar @$arr2 !=0);
 my @tmp=();
 foreach my $e1 (@arr1){
   my $f = 0;
   foreach my $e2 (@arr2){
     if ($e1 eq $e2){
       $f=1;
       last;
     }
   }
   push  @tmp, $e1  if ($f==0);
 }
 return @tmp;
}

sub get_hash_old_virus_db{
	my %hash =();
	open(IN, "../virus.db") or die "Cannot open ../virus.db";
	while(<IN>){
		if ($_=~/^>.*?_(\w{2}_?\d+)-gi\|(\d+)/){
			$hash{$1} = 1;
		}
	}
	close IN;
	return %hash;
}
