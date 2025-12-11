#!/usr/bin/perl -w

# this program will change all the ncbi links of html files to cgi call
# because cgview gives us back all the html files with ncbi links when we submit
# .ptt file into it.
# Usage: perl change_link.pl <absolute_dir_path>
# 

my $dir = $ARGV[0];
chdir  "$dir/region_series";
my $list = `ls`;
my @files = split ("\n", $list);
my $num= $dir;
$num =~s/.*\///;
my $data1 = `cat $dir/png_input`;
 
foreach my $file (@files){
	open(IN, $file) or die "Cannot open $file";
	open(OUT,">$file.tmp") or die "Cannot write $file.tmp";
	while(<IN>){
		if ($_ =~/http:\/\/www\.ncbi\.nlm\.nih\.gov\/entrez\/query\.fcgi.*?=(\d+)".*overlib\('(\d+)\.\.(\d+)/){
			 my $pp_id= $1;
			 my $start = $2;
		           my $end = $3;
			 
			 my $ppid= $pp_id;
			 $ppid =~s/\d+//g;# means $pp_id is a pure digital number, it is a gi number
			 if (length($ppid)==0){
				$pp_id = get_ppid($pp_id, $data1, $start, $end);  
			 }
			 $_ =~s/http:\/\/www\.ncbi\.nlm\.nih\.gov\/entrez\/query\.fcgi.*?\d+"/http:\/\/184.73.211.12\/phage\/cgi-bin\/get_gene_card.cgi\?dir=$dir&id=$pp_id"/;
			
			
		}
		print OUT $_;
	}
	close IN;
	close OUT;
	system("mv -f $file.tmp $file");
}
exit;

# if user input raw sequence for the case. $pp_id is locous tag number
# if user input NC number or gi number, $pp_id is gi number, if like that, we change gi number into locou tag number for the link
sub get_ppid{
	my $gi = shift;
	my $data1 = shift;
	my $start= shift;
	my $end= shift;	
	
	if ($data1 =~/$start\s+$end.*?;\s+(.*?\S+)/ ){ # pp_1234 or bma0757 or other;
		my $pp_id = $1;
		$pp_id =~s/;//;
		return $pp_id;
	}	
	return '';
}
