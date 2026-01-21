#/usr/bin/perl -w


# Script to create .json formatted file for the final PHASTEST output. This version also outputs COG
# data, retrieved from NCBI.
#
# Retrieving all COG takes very long time; this code was used for MiMeDB project in 2022. It is
# unsuitable for PHASTEST, but it might be useful for future projects.
#
# Input: 
#	ARGV[0]: extract_result.txt - Containing annotated proteins of each region, and their position in bp.
#	ARGV[1]: true_defective_prophage.txt - Result of all annotated proteins in each region.
#	ARGV[2]: Job ID.
#	ARGV[3]: Job category (-s|-c|-g).
#	[JOB_ID]_contig_positions.txt (if ARGV[3] == "-c")
#
# Output: 
#	.json format file showing all annotated proteins (both phage and bacterial).
#	.json format file containing all prophage region data.
#
# if not exists $ARGV[1], it will caterize with phage spcies. if exits, it will caterize by protein type.
# files involved: .faa
# usage :perl make_png.pl <extract file>  <true_defective_prophage.txt>  <output_file>

use Cwd;
use Data::Dumper;

# These modules are not installed on Botha cluster - run on your own machine!
use LWP::Simple;
use JSON::XS;

my $extract_file=$ARGV[0];
my $true_file = $ARGV[1];
my $job_id = $ARGV[2];
my $flag = $ARGV[3];
my %contig_pos = ();

if ($flag eq '-c' || -e "$ENV{PHASTEST_HOME}/JOBS/$job_id/$job_id\_contig_positions.txt") {
	$flag = '-c';	# Contig job may still have '-g' flag, if it was submitted using accession number.
}
get_contig_positions(\%contig_pos) if $flag eq "-c"; # can be accessed like $contig_pos{key}[0]

my %hash3 =();
get_protein_sequence_position(\%hash3);

my $ref_name ='';
my $seq_leng='';
my $or_name ='';
my $fna_file =`ls ../*.fna`;

open(IN2, $fna_file);
while(<IN2>){
	if ($_=~/>.*ref\|(.*?)\|\s*(.*)/){
		$ref_name=$1;
		$or_name = $2;
	}else{
		chomp($_);
		$seq_leng .= $_;
	}
}
$seq_leng = length($seq_leng);
close IN2;

my $ptt_file =`ls ../*.ptt`;
my %ptt_hash = ();
my %GO_comp_hash = ();
my %GO_func_hash = ();
my %GO_proc_hash = ();
my %PID_hash = ();

open(IN3, $ptt_file);
while (<IN3>) {
	if ($_ =~ /^\d+\.\.\d+\s+\S+\s+\S+\s+\S+\s+(\S+)\s+(\S+)\s+(\S+)\s+\S+\t+(NONE|.*?\;)\t+(NONE|.*?\;)\t+(NONE|.*?\;)\t+\"(.*)\"/) {
		$ptt_hash{$2} = $3;
		$PID_hash{$2} = $1;

		my @comp = split(";", $4);
		my @func = split(";", $5);
		my @proc = split(";", $6);

		$GO_comp_hash{$2} = JSON::XS->new->ascii->allow_nonref->encode(\@comp);
		$GO_func_hash{$2} = JSON::XS->new->ascii->allow_nonref->encode(\@func);
		$GO_proc_hash{$2} = JSON::XS->new->ascii->allow_nonref->encode(\@proc);
	}
}
close IN3;

my $protein_numbers = () = `cat $extract_file` =~ /\d+\.\.\d+/gi;
my $regions_numbers = () = `cat $extract_file` =~ /#### region/gi;

open(IN2, $extract_file) ;
open (OUT, "> json_input") or die "Cannot write json_input";
	my $start;
	my $end;
	my $strand;
	my $count = 1;
	my %hash =();
	my %hash1=();
	my $region ='';
	my $last_region='';
	my $region_start ='';
	my $region_end ='';
	my $flag_1;
	my $index = 0;
	my $class;
	my $region_index = '';
	my $counter = 0;

	print OUT "[\n";
	while(<IN2>){
		if ($_=~/^\s*$/){
			next;
		}		
		if ($_=~/^####\s(.*)\s####/){

			if ($1 =~ /region\s(\d+)/) {
				$region = $1;
			} else {
				$region = "Bacterial";
			}

			$region = $1;
			$region_start ='';
			$region_end ='';
			$flag_1 = 1;
			next;
		}
		
		if ($_=~/^\d+\.\.\d+/ or $_=~/^complement\(\d+\.\.\d+\)/){
			$counter++;
			my @array = split (/\s\s\s+/, $_);
			if ($array[0]=~/complement\((\d+)\.\.(\d+)\)/){
				$start = $1 ;
				$end = $2;
				$strand = '-';
			}elsif ($array[0]=~/(\d+)\.\.(\d+)/){
				$start = $1 ;
				$end = $2;
				$strand = '+';
			}
			if ($flag_1 ==1) {
				$region_start =$start;
				$flag_1=0;
			}
			$region_end =$end;
			$hash1{$region}="$region_start\|$region_end";

			my $pro_seq = get_pro_seq_from_hash($start, $end, \%hash3);

			my $protein_name;

			if ($array[1]=~/PHAGE_|PROPHAGE_|ANTIBIOTIC_RESISTANCE|VIRULENCE_PROTEIN|PROTEIN_TOXIN|PATHOGENICITY_ISLAND|TRANSCRIPTION_FACTOR|DIFFERENTIAL_GENE_REGULATION/){
					if ($array[1]=~/(.*?)\:(.*)/){
						$array[1]= $1;
						$protein_name = $2;
					}
					$protein_name .=";$array[1]";
					$class = 'phage';

					if ($protein_name =~/integrase/i or $protein_name=~/integrase/i){
						$array[1]= "Integrase";
					}elsif ($protein_name=~/head/i or $protein_name=~/capsid/ or $protein_name=~/coat/i) {
						$array[1]= "Head_protein";
					}elsif ($protein_name=~/fiber/i ) {
						$array[1]= "Fiber_protein";
					}elsif ($protein_name=~/tail/i) {
						$array[1]= "Tail_protein";
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
					}elsif ($protein_name=~/antirepressor/i) {
						$array[1]= "Antirepressor";
					}elsif ($protein_name=~/repressor/i) {
						$array[1]= "Repressor";
					}elsif ($protein_name=~/endonuclease/i) {
						$array[1]= "Endonuclease";
					}elsif ($protein_name=~/exonuclease/i) {
						$array[1]= "Exonuclease";
					}elsif ($protein_name=~/membrane/i) {
						$array[1]= "Membrane_protein";
					}elsif ($protein_name=~/neck/i) {
						$array[1]= "Neck_protein";
					}elsif ($protein_name=~/regulator/i or $protein_name=~/regulatory/i) {
						$array[1]= "Regulatory_protein";
					}elsif ($protein_name=~/replication/i) {
						$array[1]= "Replication_protein";
					}elsif ($protein_name=~/inhibitor/i) {
						$array[1]= "Inhibitor_protein";
					}elsif ($protein_name=~/kinase/i) {
						$array[1]= "Kinase";
					}elsif ($protein_name=~/endolyn/i) {
						$array[1]= "Endolyn";
					}elsif ($protein_name=~/holin/i) {
						$array[1]= "Holin";
					}elsif ($protein_name=~/endopeptidase/i) {
						$array[1]= "Endopeptidase";
					}elsif ($protein_name=~/crossover/i or $protein_name=~/junction/i) {
						$array[1]= "Crossover_junction_protein";
					}elsif ($protein_name=~/endodeoxyribonuclease/i) {
						$array[1]= "Endodeoxyribonuclease";
					}elsif ($protein_name=~/helicase/i) {
						$array[1]= "DNA_Helicase";							
					}else{
						$array[1]= "Phage-like_protein"
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
				#967646..967792                     hypothetical protein BA_0430 [Bacillus anthracis str. Ames] gi|30260595|ref|NP_842972.1|;  BASYS_01049     9e-20               LKKILALLPILLVAGLFTFSADNQQTKDKQEASEPVVQRMMTDPGGGW
				$protein_name = $array[1];
				$class = 'bacterial';

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
					$hash{$array[1]} = 1;
					chomp($array[$#array]);
					$pro_seq = $array[$#array];
				}elsif ($array[1]=~/(phage.*?);/ ){
					$array[1]= $1;
					$protein_name =~s/;\s*([\w_]+[\d\.]+)\s*$//;
					$protein_name =$1."; $protein_name";
					$protein_name .=";$array[1]";
				}elsif ($array[1]=~/^(tRNA)\-\S+$/ or $array[1]=~/^(tmRNA)\,/){
					$array[1] = $1;
					$hash{$array[1]} = 0;
					chomp($array[$#array]);
					$pro_seq = $array[$#array];
				}elsif ($array[1]=~/^\S+rRNA$/ or $array[1]=~/^(.* ribosomal RNA)$/) {
					$array[1] = "rRNA";
					$hash{$array[1]} = 0;
					chomp($array[$#array]);
					$pro_seq = $array[$#array];
				}
				else {
					$protein_name =~s/;\s*([\w_]+[\d\.]+)\s*$//;
					$protein_name =$1."; $protein_name";
					$array[1] ='Non_phage-like_protein';
				}
			}
			check_hash(\%hash, $array[1], \$count);
			$index++;

			$array[2] = "null" if $array[2] eq "N/A";
			my $PP_tag = $1 if $protein_name =~ /(PP_\d+)/;
			my $loc_tag = $ptt_hash{$PP_tag};
			my $prot = "";
			my $seq_length = $end - $start + 1;

			if ($array[1] ne "Attachment_site" && $array[1] ne "rRNA" && $array[1] ne "tRNA" && $array[1] ne "tmRNA") {
				$seq_length = ($seq_length / 3) - 1;
				$seq_length .= " aa";
			}
			else {
				$seq_length .= " bp";
			}

			my $mol_weight = "null";
			
			if ($array[1] ne "Attachment_site" && $array[1] ne "rRNA" && $array[1] ne "tRNA" && $array[1] ne "tmRNA") {
				$mol_weight = calculate_weight($pro_seq);
				$mol_weight .= " amu";
			}

			my $GO_comp = "\"-\"";
			my $GO_func = "\"-\"";
			my $GO_proc = "\"-\"";
			my $PID = "-";

			$GO_comp = $GO_comp_hash{$PP_tag} if $GO_comp_hash{$PP_tag} ne "[\"NONE\"]" && $GO_comp_hash{$PP_tag} ne "";
			$GO_func = $GO_func_hash{$PP_tag} if $GO_func_hash{$PP_tag} ne "[\"NONE\"]" && $GO_func_hash{$PP_tag} ne "";
			$GO_proc = $GO_proc_hash{$PP_tag} if $GO_proc_hash{$PP_tag} ne "[\"NONE\"]" && $GO_proc_hash{$PP_tag} ne "";
			$PID = $PID_hash{$PP_tag} if defined($PID_hash{$PP_tag});

			print OUT "\t{\n";
			if ($flag ne "-c") {
				$prot = {
					"index" => $index,
					"phage_bac_class" => "\"$class\"",
					"region_index" => "\"$region\"",
					"locus_tag" => "\"$loc_tag\"",
					"type" => "\"$array[1]\"",
					"name" => "\"$protein_name\"",
					"PID" => "\"$PID\"",
					"sequence_length" => "\"$seq_length\"",
					"start" => $start,
					"stop" => $end,
					"strand" => "\"$strand\"",
					"molecular_weight" => "\"$mol_weight\"",
					"GO_component" => $GO_comp,
					"GO_function" => $GO_func,
					"GO_process" => $GO_proc,
					"e-value" => $array[2],
					"protein_sequence" => "\"$pro_seq\""
				};
				
				foreach my $i ("index", "phage_bac_class", "region_index", "locus_tag", "type", "name", "PID", "sequence_length", 
				"start", "stop", "strand", "molecular_weight", "GO_component", "GO_function", "GO_process", "e-value", "protein_sequence") {
					$prot->{$i} =~ s/\\/\-/;
					print OUT "\t\t\"$i\":$prot->{$i}";
					$i ne "protein_sequence" ? (print OUT ",\n") : (print OUT "\n");
				}
			}
			else {
				my $contig = "NULL";
				my $contig_start = -1;
				my $contig_end = -1;

				foreach (keys %contig_pos){
					if ($start >= $contig_pos{$_}[0] && $end <= $contig_pos{$_}[1]) {
						$contig = $_;
						$contig_start = $start - $contig_pos{$_}[0];
						$contig_end = $end - $contig_pos{$_}[0];
						last;
					}
				}

				$prot = {
					"index" => $index,
					"phage_bac_class" => "\"$class\"",
					"region_index" => "\"$region\"",
					"locus_tag" => "\"$loc_tag\"",
					"type" => "\"$array[1]\"",
					"name" => "\"$protein_name\"",
					"PID" => "\"$PID_hash{$PP_tag}\"",
					"sequence_length" => "\"$seq_length\"",
					"start" => $start,
					"stop" => $end,
					"strand" => "\"$strand\"",
					"contig_tag" => "\"$contig\"",
					"contig_start" => $contig_start,
					"contig_end" => $contig_end,
					"molecular_weight" => "\"$mol_weight\"",
					"GO_component" => $GO_comp,
					"GO_function" => $GO_func,
					"GO_process" => $GO_proc,
					"e-value" => $array[2],
					"protein_sequence" => "\"$pro_seq\""
				};

				foreach my $i ("index", "phage_bac_class", "region_index", "locus_tag", "type", "name", "PID", "sequence_length", 
				"start", "stop", "strand", "contig_tag", "contig_start", "contig_end", "molecular_weight", "GO_component", 
				"GO_function", "GO_process", "e-value", "protein_sequence") {
					$prot->{$i} =~ s/\\/\-/;
					print OUT "\t\t\"$i\":$prot->{$i}";
					$i ne "protein_sequence" ? (print OUT ",\n") : (print OUT "\n");
				}
			}
			print OUT "\t},\n" unless $counter == $protein_numbers;
			print OUT "\t}\n" if $counter == $protein_numbers;
		}
	}

	print OUT "]";
	close OUT;

	open (OUT2, "> json_input_regions") or die "Cannot write regions_json_input";
	print OUT2 "[\n";
	my %hash2=();
	my %gc_hash=();
	my %name_hash=();
	my $counter = 0;
	get_hash2($true_file, \%hash2, \%gc_hash, \%name_hash); 
	foreach my $k (sort {$a<=>$b} (keys %hash1)){

		if ($k eq "Bacterial") {
			next;
		}

		$counter++;
		my $t = $hash2{$k};
		my $gc = $gc_hash{$k};
		my $a = $name_hash{$k};
		my @pos = split(/\|/, $hash1{$k});
		my $region;
		
		if ($flag ne "-c") {
			$region = {
				"region" => $k,
				"start" => $pos[0],
				"stop" => $pos[1],
				"completeness" => "\"$t\"",
				"most_common_phage" => "\"$a\"",
				"GC" => $gc
			};

			print OUT2 "\t{\n";

			foreach my $i ("region", "start", "stop", "completeness", "most_common_phage", "GC") {
				print OUT2 "\t\t\"$i\":$region->{$i}";
				$i ne "GC" ? (print OUT2 ",\n") : (print OUT2 "\n");
			}
		}
		else {
			my $contig = "NULL";
			my $contig_start = -1;
			my $contig_end = -1;

			foreach (keys %contig_pos){
				if ($pos[0] >= $contig_pos{$_}[0] && $pos[1] <= $contig_pos{$_}[1]) {
					$contig = $_;
					$contig_start = $contig_pos{$_}[0];
					$contig_end = $contig_pos{$_}[1];
					last;
				}
			}

			$region = {
				"region" => $k,
				"start" => $pos[0],
				"stop" => $pos[1],
				"contig_tag" => "\"$contig\"",
				"contig_start" => $contig_start,
				"contig_end" => $contig_end,
				"completeness" => "\"$t\"",
				"most_common_phage" => "\"$a\"",
				"GC" => $gc
			};

			print OUT2 "\t{\n";

			foreach my $i ("region", "start", "stop", "contig_tag", "contig_start", "contig_end", "completeness", "most_common_phage", "GC") {
				print OUT2 "\t\t\"$i\":$region->{$i}";
				$i ne "GC" ? (print OUT2 ",\n") : (print OUT2 "\n");
			}
		}
		
		print OUT2 "\t},\n" unless ($counter == $regions_numbers);
		print OUT2 "\t}\n" if ($counter == $regions_numbers);
	} 
	print OUT2 "]\n";
	close OUT2;

	close IN2;
exit;

sub get_hash2{
	my $file = shift;
	my $hash2=shift;
	my $gc_hash = shift;
	my $name_hash = shift;
	open(IN4, $file) or die "cannot open $file\n";
	
	while(<IN4>){
		if ($_=~/(\d+)\s+\S+\s+(\w+).*\s+\w+\s+\d+\s+(\S+?),.*\s(\d+\.\d+)/){
		#                                  1              39k                      true(110)                     integrase,capsid,tail,head                   1738016-1777431          0                        53                      33                               17                               90.8%                            3                                yes                              12                               PHAGE_pseudo_D3                            7                                21.2%                         
			$hash2->{$1} = $2;
			$gc_hash->{$1} = $4;
			my @s = split(/\(/, $3);
			$name_hash->{$1} = $s[0];
		}
	}
	close IN4;
}
# get protein sequence from hash 
sub get_pro_seq_from_hash{
	my ($start, $end, $hash)= @_;
	my $reg_ex = "$start..$end";
	foreach my $key(keys %$hash){
		if ($key eq $reg_ex){
			return  $$hash{$key};
		}
	}
	return '';
}
# get protien sequence and position from .faa file 
sub get_protein_sequence_position{
	my $hash = shift;
	my $faa = `ls ../*.faa`;
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
	foreach my $k (keys %{$hash}){
		if ($k eq $arr){
			$found=1;
			last;
		}
	}
	if ($found ==0){
		$hash->{$arr} = ++$$count;
	}
}

sub get_contig_positions{
	# Receive hash reference, and modify hash directly using those references.
	my ($hash) = @_;

	open (IN, "< $ENV{PHASTEST_HOME}/JOBS/$job_id/$job_id\_contig_positions.txt") or die "Cannot open contig positions: $!\n";
	while (<IN>) {
		$_ =~ /^(.*)\s(\d+)\s+(\d+)\s+\d+$/;
		my @arr = ($2, $3);
		$hash->{$1} = \@arr;
	}
	close IN;
}

sub calculate_weight {
	my ($seq) = @_;
	my %residue = (
		"A" => 71.08,		"C" => 103.14,		"D" => 115.09,		"E" => 129.12,
		"F" => 147.18,		"G" => 57.06,		"H" => 137.15,		"I" => 113.17,
		"K" => 128.18,		"L" => 113.17,		"M" => 131.21,		"N" => 114.11,
		"P" => 97.12,		"Q" => 128.14,		"R" => 156.2,		"S" => 87.08,
		"T" => 101.11,		"V" => 99.14,		"W" => 186.21,		"Y" => 163.18
	);

	my $len = length($seq);
	my @seqs = split("", $seq);
	my $weight = 0;

	foreach my $i (@seqs) {
		$weight += $residue{$i};
	}
	my $result = $weight + (18.01);
	return $result;
}