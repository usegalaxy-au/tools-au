#/usr/bin/perl -w

use Cwd;
use File::Glob;
use Data::Dumper;
# this program is used to summarize the result in file  region_phage_percentage.txt
# perl get_true_region.pl <scan output file>  <extract file> <output file>

# input: extract_result.txt
# output: true_defective_phage.txt
my $phage_percentage_threshold = 70; # percentage of phage proteins+hypo proteins in all proteins of each region
my $protein_mim_num= 15; # number of protein count in each region
my $phage_in_perc = 30; # percentage of most common phage proteins in total phage proteins
my $homo_threshold = 3; # homolog num
my $homo_perc_threshold = 40; # %40 of proteins have homolog number over $homo_threshold
my $min_pro_num = 40; #minimum number of proteins in the region
my $min_region_size = 30 ; #minimun size of the region is 30k;
my $multiple_dev = 1.5; # from http://www.ncbi.nlm.nih.gov/pmc/articles/PMC3280268/ , article : PIPS: Pathogenicity Island Prediction Software

my $scan_output =$ARGV[0];
my $extract_file = $ARGV[1];
my $output_file = $ARGV[2];
my $p_flag = ($scan_output=~/pathogenicity/)? 1 : 0;

my $seq =`cat ../*.fna`;
$seq =~s/>.*?\n//s;
$seq =~s/[\n\s]//gs;
open(IN, $scan_output);
my $tatol_gc_perc='';
my $total_g_num=0;
my @regions=();
my $r='';
my $header='';
while(<IN>){
	if ($_=~/region (\d+) is from (\d+) to (\d+) .*?gc%:\s*(.*?).(=[-\d\.]+=.*)/){
      #Medium degenerate region 8 is from 4683605 to 4695074 and is 11470 bp in size, gc%:49.07%.=70=
		 $r=new Region();
		 $r->{num} =$1;		 
		 $r->{gc} = $4;
		 $r->{start}=$2;
		 $r->{end}=$3;
		my $tmp= $5;
		 if ($tmp=~/=([\-\d\.]+)=(.*?)=/){
			$r->{score}=$1; $r->{phage_name}= $2;
		 }elsif($tmp=~/=([\-\d\.]+)=/){
			$r->{score}=$1;
		 }
		 $r->{region_length}=int(($r->{end}-$r->{start}+1)/100)/10;# in kb unit
		 
		 if ($r->{gc} eq '' or $r->{gc}==0.00){
			my $len=$r->{end}-$r->{start}+1;
			$r->{DNA_seq}= substr($seq, $r->{start}-1, $len);
			my $sub_seq=$r->{DNA_seq};
			$sub_seq =~s/[ATat]//gs;
			my $p = length($sub_seq)/$len;
			$p = int($p * 1000)/10;
			$r->{gc} = $p;
		}
		push @regions,$r;
	}elsif ($_=~/^gi\|\d+\|ref\|\S+\|.*gc%:\s*([\d\.]+%)/){#header
		#gi|28197945|ref|NC_004556.1| Xylella fastidiosa Temecula1, complete genome[asmbl_id: NC_004556], 2519802, gc%: 51.21%
		$tatol_gc_perc=$1;
		$header=$_;
		$header=~s/\[asmbl_id:.*?\].//;
		if ($tatol_gc_perc eq '' or $tatol_gc_perc==0.00){
			my $sub_seq = $seq;
			$sub_seq =~s/[ATat]//gs;
			my $p = length($sub_seq)/length($seq);
			$p = int($p *1000) /10;
			$tatol_gc_perc = $p;
		}
	}elsif($_=~/^\d+\s+\d+/){
	#	$total_g_num++;
	}
}

close IN;

my $regions_gc_mean='';
my $standard_dev='';
my $sum =0;
my $count=0;
foreach my $r (@regions){
	$sum += $r->{gc};
	$count++;
}
if ($count!=0){
	$regions_gc_mean=$sum /$count;
	my $dev = 0;
	foreach my $r (@regions){
		$dev+=($r->{gc}- $regions_gc_mean)**2;
	}
	$standard_dev=($dev/$count)**0.5;
}
#print "Mean = $regions_gc_mean, standart_deviation=$standard_dev\n";
open(IN, $extract_file) or die "Cannot open $extract_file";
$r='';
my $full_gc =0;
while (<IN>){
	if ($_=~/^gi\|.*?gc%:\s*([\d\.]+)%/){#header
		#gi|20520074|ref|AAAC00000000| Bacillus anthracis str. A2012 main chromosome, whole genome shotgun [asmbl_id: NC_000000].5093554, gc%: 34.93%
		$full_gc=$1;
	#	print "XXX fill_gc=$full_gc\n";
		next;
	}
	elsif ($_=~/#### Bacterial ####/){
		last; # Bacterial region, exit.
	}
	elsif ($_=~/#### region (\d+) ####/){
		$r=look_for_region_obj($1, \@regions);
		$r->{calculated_score} = 0;
		my $edge_value=$full_gc+$multiple_dev*$standard_dev;
		if ($r->{gc} > $edge_value){#use full_gc here to look up higher gc than average.
			$r->{gc_anormaly}='yes';
	#		print "Region $1, ".$r->{gc}." higher than $edge_value\n";
			$r->{calculated_score} +=10 if ($p_flag ==1); # for gc content in pathogeniciy
		}
		next;
	}
	elsif ($_=~/^.*?(\d+)\.\.(\d+)\)*\s\s\s\s+(.*?)\s\s\s\s+(.*?)\s\s\s\s+(.*?)/){
    #	complement(209159..210550)         germination protein YpeB [Clostridium clariflavum DSM 19732] gi|374294546|ref|YP_005044737.1|;  PP_00213     1e-174              LGIRDKLLDFKRRLSDRKMYSVVIVLIAAVAAWGIYQYKRAADLRQELDNQYNRAFFEMVSYVNNVESLL
    #   complement(207943..209022)         PHAGE_Entero_EF62phi: N/A; PP_00212; phage(gi384519704)                              1e-06               VEKGGEKAGGLTRTDSGVLRPNVVDASILFSGIIILFVLTGYRVQSREFYSGILITEFVIMLLPALLFVA
		my $g=new Gene();
		$g->{start}=$1; $gi->{end}=$2; $gi->{protein_name}=$3; $gi->{evalue}=$4; $gi->{protein_seq}=$5;
		if ($_=~/^complement/){
			$gi->{strand}=-1;
		}else{
			$gi->{strand}=1;
		}
		if ($gi->{protein_name} !~/^(attL|attR|tRNA|tmRNA|rRNA)/){
			$r->{protein_number}++;
		}
		if ( ($p_flag==0 && $gi->{protein_name}=~/(integrase|capsid|fiber|tail|plate|transposase|coat|head|neck|scaffold|portal|terminase|protease|lysis|lysin|envelope|virion|viron|injection|flippase|recombinase|structural)/g) #pahge
			or ($p_flag==1 && $gi->{protein_name}=~/(ANTIBIOTIC_RESISTANCE|VIRULENCE_PROTEIN|PROTEIN_TOXIN|PATHOGENICITY_ISLAND|TRANSCRIPTION_FACTOR|DIFFERENTIAL_GENE_REGULATION)/)){#pathogenicity
			my $name=$1;
			if ($p_flag ==0){#phage
				$r->{calculated_score} +=10;
			}else{#pathogenicity
				$r->{calculated_score} +=5 if ($gi->{protein_name}=~/VIRULENCE_PROTEIN|PROTEIN_TOXIN|TRANSCRIPTION_FACTOR/);
			}
			$r->{specific_keyword}.="$name," if ($r->{specific_keyword} !~/$name/s); 
		}
		if (($p_flag==0 &&$gi->{protein_name}=~/^(PHAGE_|PROPHAGE_)(.*?):/) or ($p_flag==1 && $gi->{protein_name}=~/ANTIBIOTIC_RESISTANCE|VIRULENCE_PROTEIN|PROTEIN_TOXIN|PATHOGENICITY_ISLAND|TRANSCRIPTION_FACTOR|DIFFERENTIAL_GENE_REGULATION/)){
			$r->{phage_hit_protein_num}++  ;
			$r->{phage_species_hash}->{$1.$2}++ if (defined $1 and defined $2) ;
		}elsif ($gi->{protein_name}=~/^(tRNA|tmRNA|rRNA)/){
			$r->{RNA_num}++ ;
			if ($p_flag ==1 && $r->{RNA_pick} eq ''){#pathogenicity
				$r->{calculated_score} +=30;
				$r->{RNA_pick}='yes';
			}
		}elsif ($gi->{protein_name}=~/^(attL|attR)/){
			$r->{att_show}='yes';
			if ($p_flag ==1 && $r->{att_pick} eq ''){#pathogenicity
				$r->{calculated_score} +=10;
				$r->{att_pick}='yes';
			}	
		}elsif ($gi->{protein_name}=~/^hypothetical/i){
			$r->{hypothetic_protien_num}++    ;
			$r->{calculated_score} +=5 if ($p_flag ==1); #pathogenicity
		}else{#bacterial hit
			$r->{bacterial_protein_num}++;
		}
		
		$r->{total_gene_number}++;
		push @{$r->{genes}}, $g;
	}

}
close IN;
my $num=0;
foreach $r (@regions){
	$r->{specific_keyword}=~s/,$//; $r->{specific_keyword}='NA' if ($r->{specific_keyword} eq '');
        if ($r->{protein_number} != 0){
	$r->{phage_hypo_percentage}=int(($r->{phage_hit_protein_num}+$r->{hypothetic_protien_num})/$r->{protein_number}*1000)/10;
        }else{
        	$r->{phage_hypo_percentage} = 0;
        }
	$r->{phage_hypo_percentage}.="%";
	if ($p_flag ==0){#phage
		$r->{calculated_score}+=10  if ($r->{phage_hypo_percentage} >=$phage_percentage_threshold/100);
		$r->{calculated_score}+=10  if ($r->{protein_number} >=$min_pro_num);
		$r->{calculated_score}+=10  if ($r->{region_length} >=$min_region_size);
	}
	$r->{calculated_score}=150  if($r->{calculated_score}>150);
	$r->{choose_score} = ($r->{calculated_score}>$r->{score})? $r->{calculated_score}: $r->{score};
	if (	$r->{choose_score} eq '' ){
		print $r->{calculated_score}. "\n";
		print $r->{score}."\n";
		print $r->{choose_score}."\n";
	}
	if ($p_flag ==0){#phage
		if ($r->{choose_score}<70){
			$r->{completeness}="incomplete";
		}elsif($r->{choose_score} >=70 && $r->{choose_score} <=90){
			$r->{completeness}="questionable";
		}else{
		    $r->{completeness}="intact";
			$num++;
		}
	}else{#pathogenicity
		if ($r->{choose_score}<100){
            $r->{completeness}="incomplete";
        }elsif($r->{choose_score} >=100 && $r->{choose_score} <=130){
            $r->{completeness}="questionable";
        }else{
            $r->{completeness}="intact";
            $num++;
        }

	}
	$r->{phage_species_num}=scalar (keys %{$r->{phage_species_hash}});
	my $max_name='';
	my $max_num=0;
	foreach my $k(keys %{$r->{phage_species_hash}}){
		if ($r->{phage_species_hash}->{$k}>$max_num){
			$max_num=$r->{phage_species_hash}->{$k};
			$max_name=$k;
		}
	}

	$r->{most_common_phage_name}= ($r->{most_common_phage_name} eq '') ? 'None' : $max_name; 
	$r->{most_common_phage_num}= $max_num;
        if ($r->{protein_number} != 0){
	$r->{most_common_phage_percentage}=int($r->{most_common_phage_num}/$r->{protein_number}*1000)/10;
        }else{
            $r->{protein_number} = 0
        }
	$r->{most_common_phage_percentage}.="%";
}


open(OUT, "> $output_file");
print OUT get_header($num);
print OUT $header;
print_header(\*OUT);
print_out(\*OUT, \@regions);
close OUT;	
print "$output_file generated!\n";
exit;

sub print_header{
	my $out =shift;
	my $line = sprintf("%-30s    %-10s     %-20s     %-25s     %-40s     %-20s     %-20s     %-20s    %-30s   %-30s   %-30s   %-30s   %-30s   %-30s   %-40s   %-30s   %-30s   %-30s\n", "", "REGION", "REGION_LENGTH", "COMPLETENESS(score)","SPECIFIC_KEYWORD",  "REGION_POSITION","RNA_NUM", "TOTAL_PROTEIN_NUM", "PHAGE_HIT_PROTEIN_NUM",   "HYPOTHETICAL_PROTEIN_NUM","PHAGE+HYPO_PROTEIN_PERCENTAGE", "BACTERIAL_PROTEIN_NUM", "ATT_SITE_SHOWUP", "PHAGE_SPECIES_NUM", "MOST_COMMON_PHAGE_NAME(hit_genes_count)",  "FIRST_MOST_COMMON_PHAGE_NUM", "FIRST_MOST_COMMON_PHAGE_PERCENTAGE", "GC_PERCENTAGE");
	print $out $line;
	$line='';
	for($i=0; $i<550; $i++){
		$line .='-';
	}
	$line = sprintf("%-28s     %s\n", "", $line);
	print $out $line;
}

sub look_for_region_obj{
	my ($num, $regions) =shift;
	foreach my $r (@regions){
		if ($r->{num}==$num){
			return $r;
		}
	}
	return '';
}

sub get_phage_info{
	my $rec=shift;
	if (`cat region_PHAGEs.txt`=~/$rec\t(.*)/){
		return $1
	}
	return '';
}


sub print_out{
	my ($out, $regions)=@_;
	foreach my $r(@$regions){
		if (-e "region_PHAGEs.txt"){
			$r->{most_common_phage_name}=get_phage_info($r->{num});
			my @tmp=$r->{most_common_phage_name}=~/\((\d+)\)/gs;
			$r->{most_common_phage_percentage}=$tmp[0];
			if ($r->{protein_number} != 0){
				$r->{most_common_phage_percentage}= int($tmp[0]/$r->{protein_number} *10000)/100;
         	}else{
				$r->{most_common_phage_percentage}=0
			}
			$r->{most_common_phage_percentage}.="%";
		}	
		$r->{most_common_phage_name}= "\'\'" if ($r->{most_common_phage_name} eq '');
		$region_positon = $r->{start}."-".$r->{end};
		$region_positon =~ s/\s+/,/g;
		$line = sprintf("%-30s    %-10s     %-20s     %-25s     %-40s     %-20s     %-20s     %-20s    %-30s   %-30s   %-30s   %-30s   %-30s   %-30s   %-40s   %-30s   %-30s   %-30s\n", 
		"", $r->{num},$r->{region_length}."Kb", $r->{completeness}."(".$r->{choose_score}.")", $r->{specific_keyword},  $region_positon, $r->{RNA_num}, $r->{protein_number}, 
		$r->{phage_hit_protein_num},  $r->{hypothetic_protien_num}, $r->{phage_hypo_percentage},$r->{bacterial_protein_num}, $r->{att_show}, $r->{phage_species_num}, 
		$r->{most_common_phage_name}, $r->{most_common_phage_num}, $r->{most_common_phage_percentage}, $r->{gc});
		print $out $line;
	}
	
}

sub get_header{
	my $num = shift;
	chomp($num);
	my $header="Criteria for scoring prophage regions (as intact, questionable, or incomplete):\n".
		"Method 1:\n".
		"1. If the number of certain phage organism in this table is more than or equal to 100% of the total number of CDS of the region,\n".
		"   the region is marked with total score 150. If less than 100%, method 2 and 3 will be used.\n\n". 
		"Method 2:\n".
		"1. If the number of certain phage organism in this table  is more than 50% of the total number of CDS of the region, that phage \n".
		"   organism is considered as the major potential phage for that region; the percentage of the total number\n".
		"   of that phage organism in this table in the  total number of proteins of the region is calculated and \n".
		"   then multipled by 100; the percentage of the length of that phage organism in this table in the length \n".
		"   of the region is calculated and then multipled by 50 (phage head's encapsulation capability is considered).\n\n".
		"Method 3:\n".
		"1. If any of the specific phage-related keywords (such as 'capsid', 'head', 'integrase', 'plate', 'tail', 'fiber',\n".
 		"   'coat', 'transposase', 'portal', 'terminase', 'protease' or 'lysin') are present, the score will be increased \n".
		"   by 10 for each keyword found.\n".
		"2. If the size of the region is greater than $min_region_size Kb, the score will be increased by 10.\n".
		"3. If there are at least $min_pro_num proteins in the region, the score will be increased by 10.\n".
		"4. If all of the phage-related proteins and hypothetical proteins constitute more than $phage_percentage_threshold% of\n". 
		"   the total number of proteins in the region, the score will be increased by 10.\n\n".
		"Compared the total score of method 2 with the total score of method 3, the bigger one is chosen as the total score of the region.\n".
		"If the region's total score is less than 70, it is marked as incomplete; if between 70 to 90, it is marked as questionable; if greater than 90, it is marked as intact.\n".
		"   \n\n\n".
		"Totally $num intact prophage regions have been identified.\n".
		"\n\n\n\n";
	return $header;
}

package Region;
sub new{
	my $class=shift;
	my $self={ 
		num=>'',
		start=>'',
		end=>'',
		region_length=>'',
		gc=>'',
		gc_anormaly=>'',
		score=>'',
		calculated_score=>'',
		DNA_seq=>'',
		total_gene_number=>0,
		genes=>[],
		most_common_phage_name=>'',
		most_common_phage_num=>0,
		most_common_phage_percentage=>0,
		RNA_num=>0,
		RNA_pick=>'',
		att_show=>'no',
		att_pick=>'',
		comleteness=>'',
		specific_keyword=>'',
		protein_number=>0,
		phage_hit_protein_num=>0,
		hypothetic_protien_num=>0,
		phage_hypo_percentage=>0,
		phage_species_num=>0,
		phage_species_hash=>{},
		choose_score=>'',
		bacterial_protein_num=>0
		
	};
	bless $self, $class;
	return $self;
}
package Gene;
sub new {
	my $class =shift;
	my $self ={
		start=>'',
		end=>'',
		strand=>'',
		evalue=>'',
		protein_name=>'',
		protein_seq=>''

	};
	bless $self, $class;
	return $self;
}
1;
