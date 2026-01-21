#!/usr/bin/perl -w
#===============================================================================
#
#         FILE:  get_genome_NC_protein_gis.pl
#
#        USAGE:  ./get_genome_NC_protein_gis.pl  $genome_dir
#				 Default: $genome_dir is /home/prion/phage/DB/temp_bac/
#
#  DESCRIPTION:  this program will make a table that first column is genome NC and 
#  							second column the protein gi(NC) from that genome.
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  YOUR NAME (), 
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  03/05/2013 11:46:00 AM
#     REVISION:  ---
#===============================================================================

if (scalar @ARGV!=1){
	print STDERR "Usage : perl get_genome_NC_protein_gis.pl <Genome_dir>\n";
	exit(-1);
}

my $genome_dir = $ARGV[0];
my $working_dir = "/home/prion/phaster-app/DB/temp_bac/";
$working_dir = $genome_dir  if (defined $genome_dir and  $genome_dir ne '');

chdir $working_dir;
my $genome_list = `ls`;

open (OUT, ">z_genome_NC_protein_gis");
print OUT "#GENOME_NC\tPROTEIN_GIS\n";
foreach my $dir (split "\n", $genome_list){
	next if (!-d $dir);
	my $faa_file_list = `ls $dir`;
	foreach my $f (split "\n", $faa_file_list){
		my $data = `grep '>' $dir/$f`;
		my %hash = $data=~/gi\|(\d+)\|\w{1,3}\|(\S+)\|/gs;
		my $str='';
		foreach my $k(sort {$a<=>$b} keys %hash){
			$str.="$k($hash{$k}),";
		}
		$str=~s/,$//;
		$f =~s/\.faa//;
		if ($str eq ''){
			print "No gis from $f\n";
		}
		print OUT "$f\t$str\n";
	} 
}
close OUT;

exit;
