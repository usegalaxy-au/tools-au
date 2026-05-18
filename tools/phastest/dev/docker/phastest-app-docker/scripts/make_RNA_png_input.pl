#/usr/bin/perl -w


#this program is used to create an input file for all java program 
# to create a png file
# input: list of NC_XXXX folder names
#output : a png file that show the distribution of regions and ORFs on bacterial genome.
# usage :perl make_RNA_png_input.pl <input_file> <output_file>
use Cwd;
use Data::Dumper;

my $output = $ARGV[1];
my $fn='';
if (defined $ARGV[1]){
	$fn = $ARGV[1];
}

my %hash3 =();
get_protein_sequence_position(\%hash3);

open(IN2, $ARGV[0]) ;
open (OUT, ">$output") or die "Cannot write $output";
	my $start;
	my $end;
	my $strand;
	my $count =1;
	my %hash =();
	my %hash1=();
	my $region ='';
	my $last_region='';
	my $region_start ='';
	my $region_end ='';
	my $rx = "%-7s   %-12s  %-12s  %-4s  %-25s  %-70s   %-8s   %s\n";
	my $header = "         from       to      strand      match      RNA_name     EVALUE     match_sequence\n";
	$flag_1 = 0;
	while(<IN2>){
		if ($_=~/^\s*$/){
			next;
		}
		if ($_=~/gi\|.*\|ref\|.*\|(.*)/ or $_=~/^>(.*)/){
		# gi|53723370|ref|NC_006348.1| Burkholderia mallei ATCC 23344 chromosome 1, complete sequence [asmbl_id: NC_006348], 3510148, gc%: 68.15%
		# gi|00000000|ref|NC_000000|DEFINITION  Escherichia coli str. K-12 substr. MG1655 chromosome, complete [asmbl_id: NC_000000].4639677, gc%: 50.79%
			$name = $1;
			$name =~s/, complete.*?\[.*?\s*/ \[/;
			$name =~s/[\.,]\s*(\d+)$/\. $1/;
			print OUT ">$name\n";
			print OUT $header;
			next;
		}
		
		if ($_=~/^#### region (\d+)/){
			#print OUT $_;
			if ($region ne ''){
				$hash1{$region}="$region_start\|$region_end";
			}
			$region = $1;
			$region_start ='';
			$region_end ='';
			$flag_1 = 1;
			next;
		}
		if ($_=~/^\d+\.\.\d+/ or $_=~/^complement\(\d+\.\.\d+\)/){
			
			@array = split (/\s\s\s+/, $_);
			if ($array[0]=~/complement\((\d+)\.\.(\d+)\)/){
				$start = $1 ;
				$end =$2;
				$strand = '-';
			}elsif ($array[0]=~/(\d+)\.\.(\d+)/){
				$start = $1 ;
				$end =$2;
				$strand = '+';
			}
			if ($flag_1 ==1) {
				$region_start =$start;
				$flag_1=0;
			}
			$region_end =$end;
			my $pro_seq = get_pro_seq_from_hash($start, $end, \%hash3);
			
			my $rest = $1;
			my $protein_name ;
			if ($array[1]=~/[PHAGE|PROPHAGE]_/i){
				$protein_name = $rest;
				
				$protein_name .=";$array[1]";
				if ($protein_name =~/integrase/i or $protein_name=~/int/i){
					$array[1]= "Integrase";
				}elsif ($protein_name=~/head/i or $protein_name=~/capsid/ or $protein_name=~/coat/i) {
					$array[1]= "Head_protein";
				}elsif ($protein_name=~/fiber/i ) {
					$array[1]= "Fiber_protein";
				}elsif ($protein_name=~/tail/i) {
					$array[1]= "Tail_protein";
				}elsif ($protein_name=~/plate/i) {
					$array[1]= "Plate_protein";
				}elsif ($protein_name=~/plate/i) {
					$array[1]= "Plate_protein";
				}elsif ($protein_name=~/transposase/i) {
					$array[1]= "Transposase";
				}elsif ($protein_name=~/portal/i) {
					$array[1]= "Portal_protein";
				}elsif ($protein_name=~/terminase/i) {
					$array[1]= "Terminase";
				}elsif ($protein_name=~/collar/i) {
					$array[1]= "Collar_protein";
				}elsif ($protein_name=~/protease/i) {
					$array[1]= "Protease";
				}elsif ($protein_name=~/lysis/i or $protein_name=~/lysin /i ) {
					$array[1]= "Lysis_protein";
				}elsif ($protein_name=~/hypothetical/i ) {
					$array[1]= "Hypothetical_protein";
				}
				else{
					$array[1]= "Phage-like_protein";
				}
				#print "1  $protein_name\n " if ($protein_name=~/HI1522.1/);
				$protein_name=~s/;\s*([\w_]+[\d\.]+;)/;/;
				$protein_name= $1.$protein_name;
				#print "2  $protein_name\n " if ($protein_name=~/HI1522/);
				$protein_name=~s/\s*;\s*/;/g;
				$protein_name=~s/\s*;/;/g;
				$protein_name=~s/;\s*/;/g;
				#print "3  $protein_name\n " if ($protein_name=~/HI1522/);				
			}else{
				$protein_name = $array[1];
				if ($array[1] =~/; E-VALUE = (\S+);/){
					$protein_name=~s/; E-VALUE = (\S+);/;/;
					$array[2] = $1;
				}
					
				if($array[1]=~/hypothetical/i){
					$protein_name =~s/;\s*([\w_]+[\d\.]+)\s*$//;
					$protein_name =$1."; $protein_name";
					$array[1] = 'Hypothetical_protein';
					$hash{$array[1]} = 2;
					
				}elsif ($array[1]=~/attR/ or $array[1]=~/attL/ ){
					$array[1] = 'Attachment_site';
					$hash{$array[1]} =1;
					chomp($array[$#array]);
					$pro_seq = $array[$#array];
				}elsif ($array[1]=~/(tRNA)/ or $array[1]=~/(tmRNA)/ or $array[1]=~/(rRNA)/ ){
					$array[1] = $1;
					if ($array[1]=~/(tRNA)/){
						$hash{$array[1]} =0;
					}elsif($array[1]=~/(tmRNA)/){
						$hash{$array[1]} =2;
					}else{#rRNA
						$hash{$array[1]} =1;
					}		
					$pro_seq = $array[$#array];	
				}elsif ($array[1]=~/(phage.*?);/ ){
						$array[1]= $1;
						$protein_name =~s/;\s*([\w_]+[\d\.]+)\s*$//;
						$protein_name =$1."; $protein_name";
						$protein_name .=";$array[1]";
						$array[1] = "Phage-like_protein";
				}else{
						$array[1] ='Non_phage-like_protein';
						$protein_name =~s/;\s*([\w_]+[\d\.]+)\s*$//;
						$protein_name =$1."; $protein_name";
				}
			}
			check_hash(\%hash, $array[1], \$count);
			$line = sprintf ($rx, "section", $start, $end, $strand."$hash{$array[1]}", $array[1], $protein_name, $array[2], $pro_seq );
			print OUT $line;
				
		}
		
	}
	close IN2;
	if ($region ne ''){
		$hash1{$region}="$region_start\|$region_end";
	}
	print OUT "\n\n";
	#print Dumper(\%hash2);
	foreach $k (sort {$a<=>$b} keys %hash1){
		$m = $hash1{$k};
		$n = $hash1{$k};
		$t = "RNA_location";
		$gc = 0.00;
		
		$m =~s/.*\|//;
		$n =~s/\|.*//;
		$line = sprintf ("%-7s   %-3s  %-12s   %-12s   %-12s   %-12s\n", "region" , $k, $n, $m, $t, $gc);
		print OUT $line;
	} 
	close OUT;

exit;

sub get_hash2{
	my $file = shift;
	my $hash2=shift;
	my $gc_hash = shift;
	open(IN4, $file) or die "cannot open $file\n";
	
	while(<IN4>){
		if ($_=~/^\s\s\s\s\s\s+(\d+)\s+\S+\s+(\w+).*\s+(\S+)\s*$/){
		#                                  1              39k                      true(110)                     integrase,capsid,tail,head                   1738016-1777431          0                        53                      33                               17                               90.8%                            3                                yes                              12                               PHAGE_pseudo_D3                            7                                21.2%                         
			$hash2->{$1} = $2;
			$gc_hash->{$1} = $3;
			$gc_hash->{$1} =~s/%//;
				
		}
	}
	
	close IN4;

}
# get protein sequence from hash 
sub get_pro_seq_from_hash{
	my ($start, $end, $hash)= @_;
	my $reg_ex = "$start..$end";
	foreach $key(keys %$hash){
		if ($key eq $reg_ex){
			return  $$hash{$key};
		}
	}
	return '';
}
# get protien sequence and position from .faa file 
sub get_protein_sequence_position{
	my $hash = shift;
	my $faa = `ls *.faa`;
	chomp($faa);
	open(IN, $faa)or die "Cannot open $faa";
	my @arr =();
	while (<IN>){
		if ($_=~/^>.*?(\d+\.\.\d+)/){
			@arr =();
			@arr = $_=~/(\d+\.\.\d+)/g;
			foreach my $i (@arr){
				$$hash{$i} = '';
			}
			
		}else{
			chomp($_);
			foreach my $i (@arr){
				$$hash{$i} .= $_;
			}
		}
	}
	close IN;
}

sub check_hash{
	my $hash= shift;
	my $arr = shift;
	my $count=shift;
	my $found=0;
	foreach $k (keys %{$hash}){
		if ($k eq $arr){
			$found=1;
			last;
		}
	}
	if ($found ==0){
		$hash->{$array[1]} = ++$$count;
	}
}

