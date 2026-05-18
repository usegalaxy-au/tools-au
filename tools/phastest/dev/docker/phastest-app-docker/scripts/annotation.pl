#!/usr/bin/perl -w

# Notes by David Arndt, Mar 2018:
# The purpose of this script is to add annotations (human-readable descriptions of
# function) to genes in predicted prophage regions. For example, lines like
#
# 308277     00286              gi|371671534|ref|YP_004958072.1|, TAG = PHAGE_Pseudo_OBP_NC_016571, E-VALUE = 4.15e-45
#                               [ANNO] -; PP_00286
# 309101     00287              [ANNO] -; PP_00287
#
# are changed to be like
#
# 308277     00286              gi|371671534|ref|YP_004958072.1|, TAG = PHAGE_Pseudo_OBP_NC_016571, E-VALUE = 4.15e-45
#                               [ANNO] putative homing nuclease; PP_00286; phage
# 309101     00287              [ANNO] hypothetical; PP_00287
#
# Arguments include:
# non_hit_blast_output_file: BLAST output file from BLAST of "non-hit genes" (i.e. those
#   that did not have matches against the viral BD) against bacterial sequence database.
# scan_output_file: File of predicted prophage regions output by scan.pl. This file is
#   modified by annotation.pl.
# -g = GenBank input file
# -s = single FASTA sequence only

# Old comments:
# Since there is no annotation in phage finder's output if we submit the raw nucleotide sequence
# only into the server, now we complement this part after phage finder finishes. In phage finder's
# result, there is gi number there if there is blast hit on that region. We use that gi to get back
# the annotation from GENBank

print "\nCall annotation.pl <NC number> <dir-name> <virus_db> <bac_db> <non_hit_blast_output_file> <scan_output_file> <.ptt> [-s|-a|-g] [0|1]\n";
my $NC = $ARGV[0];
my $num = $ARGV[1];
my $virus_db = $ARGV[2];
my $bac_db = $ARGV[3];
my $blast_output_file = $ARGV[4];
my $scan_output_file = $ARGV[5];
my $RNA_output_file = $ARGV[6];
my $ptt_file = $ARGV[7];
my $flag = $ARGV[8];
my $anno_flag = $ARGV[9]; # 0 if only for prophage region, 1 for full annotation.

my $blast_data='';
my $t1 = time();

if (!-e $virus_db){
	print STDERR "There is no $virus_db, check\n";
	exit(-1);
}
if (!-e $bac_db ){
	print STDERR "There is no $bac_db , check\n";
	exit(-1);
}

my %hash_virus_database = ();
my %hash_non_hit_blast_data=();
my %hash_non_hit_nested=();
my %hash_bac_database=();
my %hash_bac_database_temp=();
my %hash_faa_data=();
my %hash_ptt_data=();
my %hash_ptt_keys=();

# Read phage and bacterial header line database - we use these to name the predicted proteins.
my $tt = time();
open(IN, "$virus_db") or die "Cannot open $virus_db";
while(<IN>){
	# >PHAGE_Klebsi_KP1801_NC_049848-gi|100032|ref|YP_009903546.1| u-spanin [Klebsiella phage KP1801]
	if ($_=~/ref\|(\S+)\|\s*(.*?)\n/){
		$hash_virus_database{$1} = $2;
	}
}
close IN;
print "read in $virus_db, time ". (time()-$tt). " seconds\n";

# It takes very long (30-40 sec) to read entire bacterial database, so we do it only when it's needed (for deep annotation mode).
if ((index($bac_db, "bacteria_all_select") != -1) && $flag ne "-g") {
	$tt = time();
	open(IN, "$bac_db") or die "Cannot open $bac_db";
	while(<IN>){
		# >WP_042284424.1 MULTISPECIES: DUF1456 family protein [Citrobacter]
		if ($_=~/\>(.*?)\.\d+\s(.*)/){
			$hash_bac_database{$1} = $2;
		}
	}
	close IN;
	print "read in $bac_db, time ". (time()-$tt). " seconds\n";
}

# If the output is generated from raw sequence, parse its non-hit output file.
# In blast output file, hit with lowest e-value (most confident hit) goes at the top.
if ($NC eq 'NC_000000' and $flag ne '-g'){
	if (-e $blast_output_file){
		open(IN1, $blast_output_file) or die "Failed to open scan output file: $!\n";
		while(<IN1>) {
			chomp;

			# Swissprot annotation.
			# gi|00058|ref|NC_000000|	sp|A5UB83|UVRC_HAEIE UvrABC system protein C OS=Haemophilus influenzae (strain PittEE) OX=374930 GN=uvrC PE=3 SV=1	97.7	609	14	0	1	609	1	609	0.0	1160
			if ($_=~/^gi\|(\d+)\|.*?sp\|(\S+)\|\S+\s(.*)\sOS\=/) {
				next if defined($hash_non_hit_blast_data{$1});
				my @evalue = split(" ", $_);
				$hash_non_hit_blast_data{$1}="$2 $evalue[-2]";
				$hash_bac_database{$2}=$3;
				$hash_non_hit_nested{$1}=0;
				# $1 = local gi number (a counter for each identified gene region)
				# $2 = Swissprot accession number for that given region
				# $3 = Description of the hit
			}

			# PHAST-BSD annotation.
			# gi|00002|ref|NC_000000|	WP_016400849	60.414	821	320	5	1	817	1	820	1.451925e-270	938.0	(PHAST-BSD data)
			if ($_=~/^gi\|(\d+)\|.*?\|\s+(.*?)\s/){
				next if defined($hash_non_hit_blast_data{$1});
				my @evalue = split(" ", $_);
				$hash_non_hit_blast_data{$1}="$2 $evalue[-2]";
				$hash_non_hit_nested{$1}=0;
				# $1 = local gi number (a counter for each identified gene region)
				# $2 = Pfam accession number for that given region
			}
		}
		close IN1;
	}
}

print "Blast output files reading done\n";

# Parse .ptt file for protein location and local GI.
open(IN1, $ptt_file) or die "Failed to open ptt file: $!\n";
while(<IN1>) {
	chomp;
	
	# .gbk-based .ptt files have this format.
	# 190..255	+	21	00001	thrL	PP_00001	STY_RS00005	-	thr operon leader peptide [WP_001575544.1]
	# 5683..6459	-	258	00006	yaaA	PP_00006	b0006	-	NONE	NONE	NONE	"N/A"	peroxide resistance protein, lowers intracellular iron [NP_414547.1]
	if ($_=~/(\d+)\.\.\d+\s+\+\s+\S+\s+(\S+).*\[(.*?)\]/ or $_=~/\d+\.\.(\d+)\s+\-\s+\S+\s+(\S+).*\[(.*?)\]/) {
		my @tokens = split(" ", $_);
		my $loc = $1;
		my $gi = $2;
		my $acc = $1 if $tokens[$#tokens] =~ m/\[(.*)\]/;
		my $def = $1 if $_ =~ /\"\s+(.*?) \[.*$/;
		$hash_non_hit_blast_data{$tokens[3]} = "$acc N/A";
		$hash_non_hit_nested{$tokens[3]} = 0;
		$hash_bac_database{$acc} = $def;

		# Data needed for full annotation.
		if ($anno_flag == 1) {
			$hash_ptt_data{$loc} = $gi;
			$hash_ptt_keys{$gi} = $loc;
		}

		# $1 = 5' end bp location.
		# $2 = local GI associated with that location.
		# $3 = accession number associated with that location.
	}
	# .fna-based .ptt files have this format.
	# 32749..33570	+	273	00031	-	PP_00031	-	-	NONE	NONE	NONE	"Predicted gene region."	-
	elsif ($_ =~ /(\d+)\.\.\d+\s+\+\s+\S+\s+(\S+)/ or $_ =~ /\d+\.\.(\d+)\s+\-\s+\S+\s+(\S+)/) {
		my ($loc, $gi) = ($1, $2);
		$hash_ptt_data{$loc} = $gi;
		$hash_ptt_keys{$gi} = $loc;
	}
}
close IN1;

print "Ptt file reading done\n";

my %hash_RNA_data=();
my %hash_RNA_keys=();

if (-e $RNA_output_file) {
	open (IN2, $RNA_output_file) or die "Failed to open tRNA output file: $!\n";
	while (<IN2>) {
		chomp;

		if ($_=~/section\s+(\d+)\s+(\d+).*type:(.*?)\,/) {
			$hash_RNA_data{$1} = "$3";
			#1 = phmedio.txt start region
			#2 = tRNA/rRNA identity
		}
		elsif ($_=~/section\s+(\d+)\s+(\d+).*(tmRNA.*?)\s\s\s+/) {
			$hash_RNA_data{$1} = "$3";
			#1 = phmedio.txt start region
			#2 = tmRNA consensus sequence
		}
	}
	close IN2;

	my $counter = 1;
	foreach my $k (sort {$a<=>$b} (keys %hash_RNA_data)) {
		$hash_RNA_keys{$counter++} = $k;
	}
}

if (-e $scan_output_file){
	get_annotation($scan_output_file, \%hash_non_hit_blast_data, $num, \%hash_virus_database, \%hash_ptt_data, \%hash_bac_database, \%hash_faa_data, \%hash_RNA_keys, \%hash_RNA_data);
	print "  Change $scan_output_file \n";
}
my $diff_time = time()- $t1;
print "Finish annotation.pl in $diff_time seconds\n\n";
exit(0);

# get annotation on specified file.
sub get_annotation{
	my ($scan_output_file, $hash_non_hit_blast_data, $num, $hash_virus_database, $hash_ptt_data, $hash_bac_database, $hash_faa_data, $hash_RNA_keys, $hash_RNA_data)=@_;
	my $title = '';
	open(TI, "<../$num.fna") or die "Cannot open file $!";
	while(<TI>){
		$title .= $_;
	}
   	close TI;

	# Filter the title from .fna file.
	$title =~s/>(.*?)\n.*/$1/s;
	$title =~s/[,\.]\s*$//;

	system("cp $scan_output_file $scan_output_file\_bk");
	my $phage_suffix='';
	$phage_suffix='phage' if ($scan_output_file=~/phmedio.txt/);
	open (IN, "<", $scan_output_file);
	open (OUT, ">", "$scan_output_file.tmp") or die "Cannot write $scan_output_file.tmp";
	print "Writing $scan_output_file.tmp\n";

	my %hash_anno_hits=();
	my %hash_RNA_nested=();
	my $desc;
	while(<IN>){
		# 1513250    01475              gi|1475|ref|YP_009203401.1|, TAG = PHAGE_Mannhe_vB_MhS_535AP2_NC_028853, E-VALUE = 4.91e-104
		# 								[ANNO] PP_01405; -
		if ($_=~/\d+\s+(\d+).*?ref\|(\S+)\|/){
			print OUT $_;
			OUT->flush();
			my ($gi, $acc) = ($1, $2);
			$hash_anno_hits{$gi} = 1;

			$desc = 'N/A';
			if (defined $hash_virus_database->{$acc}){
				$desc=$hash_virus_database->{$acc}; $desc=~s/\s*\[.*?\].*//;
				$desc=~s/<*>*\d+\.\.<*>*\d+//;
			}
			my $next_line='';

			$next_line = <IN>; $desc =~s/\n//g;
			$next_line=~s/\[ANNO\].*?(PP_\d+)/\[ANNO\] $desc; $1; $phage_suffix/; 
			print OUT $next_line;
			OUT->flush();
		}

		# 2273165    02052              [ANNO] PP_02052; -
		elsif ($_=~/^(\d+)\s+(\d+)\s+\[ANNO\]/i){
			$hash_anno_hits{$2} = 1;
			my $e='';
			my $acc='';
			my $end5=$1;
			my $gi_local = $2;

			if (defined $hash_non_hit_blast_data{$gi_local}){
				($acc,$e) = $hash_non_hit_blast_data{$gi_local}=~/(.*)\s(.*)/;
			}

			my $line = $_;

			# If accession number is defined.
			if (defined $hash_bac_database->{$acc}) {
				$desc=$hash_bac_database->{$acc};
				$desc =~s/\.$//; $desc =~s/\n//g;
				$line=~s/\[ANNO\]\s(PP\_\d+)/\[ANNO\] $desc; E-VALUE = $e; $1/i;
			}

			# Cannot retrieve accession number somehow.
			else{
				$line=~s/\[ANNO\]\s(PP\_\d+)/\[ANNO\] hypothetical; $1/i;
			}
			print OUT $line;
			OUT->flush();
		}

		# 1639927    tRNA               [ANNO] tRNA-Val;
		elsif ($_=~/^(\d+)\s+(tRNA|tmRNA|rRNA)\s+\[ANNO\]/) {
			$hash_RNA_nested{$1} = 0;
			print OUT $_;
			OUT->flush();
		}elsif ($_=~/^.*?\[.*?\].*gc\%/ && $_!~/gi/ ){ # [asmbl_id: NC_000000], , gc%: %
			$_= $title.$_;
			print OUT $_;
			OUT->flush();
		}else{
			print OUT $_;
			OUT->flush();
		}
	}
	close IN;
	close OUT;

	print "Finished writing $scan_output_file.tmp\n";

	if ($anno_flag == 1) {
		printBacterialResult(\%hash_non_hit_nested, \%hash_non_hit_blast_data, \%hash_ptt_keys, \%hash_bac_database, \%hash_anno_hits, \%hash_RNA_keys, \%hash_RNA_data, \%hash_RNA_nested);
	}

	open(IN, "<", "$scan_output_file.tmp") or die "Cannot open $scan_output_file.tmp";
	open(OUT, ">", "$scan_output_file") or die "Cannot write $scan_output_file";
	while (<IN>){
		print OUT $_;
		OUT->flush();
	}
	close IN;
	close OUT;
	unlink "$scan_output_file.tmp";
}

sub printBacterialResult {
	my %hash_non_hit_nested = %{$_[0]};
	my %hash_non_hit_blast_data = %{$_[1]};
	my %hash_ptt_keys = %{$_[2]};
	my %hash_bac_database = %{$_[3]};
	my %hash_anno_hits = %{$_[4]};
	my %hash_RNA_keys = %{$_[5]};
	my %hash_RNA_data = %{$_[6]};
	my %hash_RNA_nested = %{$_[7]};
	my $prev_end5 = 0;

	open (OUT, ">>", "$scan_output_file.tmp") or die "Cannot write $scan_output_file.tmp";

	print OUT "\n\n";
	OUT->flush();
	print OUT "BACTERIAL HITS\n";
	OUT->flush();
	print OUT "END5     FEATNAME           ANNOTATION OF BEST HIT FROM PFAM-A HMM HIT\n";
	OUT->flush();
	print OUT "............................................................................................................................................................................\n";
	OUT->flush();

	# Each keys are local GI number of all bacterial genes outside of prophage region.
	foreach my $k (sort keys %hash_non_hit_nested) {
		if ($hash_non_hit_nested{$k} == 0 && !defined($hash_anno_hits{$k})) {
			my $desc = 'N/A';
			my $e;
			my $acc;
			my $end5;
			my $line = 'N\A';

			if (defined $hash_non_hit_blast_data{$k}){
				($acc,$e) = $hash_non_hit_blast_data{$k}=~/(.*)\s(.*)/;
			}
			
			if (defined $hash_ptt_keys{$k}) {
				$end5 = $hash_ptt_keys{$k};
			}

			foreach my $counter (sort {$a<=>$b} (keys %hash_RNA_keys)) {
				if ($prev_end5 < $hash_RNA_keys{$counter} and $hash_RNA_keys{$counter} < $end5 and !defined($hash_RNA_nested{$hash_RNA_keys{$counter}})) {
					if (index($hash_RNA_data{$hash_RNA_keys{$counter}}, "rRNA") != -1 || 
						index($hash_RNA_data{$hash_RNA_keys{$counter}}, "ribosomal RNA") != -1) {
						print OUT "$hash_RNA_keys{$counter}\t\trRNA\t\t[ANNO] $hash_RNA_data{$hash_RNA_keys{$counter}}\n";
						OUT->flush();
					}
					elsif (index($hash_RNA_data{$hash_RNA_keys{$counter}}, "tmRNA") != -1) {
						print OUT "$hash_RNA_keys{$counter}\t\ttmRNA\t\t[ANNO] $hash_RNA_data{$hash_RNA_keys{$counter}}\n";
						OUT->flush();
					}
					else {
						print OUT "$hash_RNA_keys{$counter}\t\ttRNA\t\t[ANNO] tRNA-$hash_RNA_data{$hash_RNA_keys{$counter}}\n";
						OUT->flush();
					}
					$prev_end5 = $hash_RNA_keys{$counter};
				}
			}

			if (defined $hash_bac_database{$acc}) {
				$desc=$hash_bac_database{$acc};
			}

			if ($acc ne '') {
				$line="[ANNO] $desc; E-VALUE = $e; PP_$k";
			} else {
				$line="[ANNO] hypothetical; PP_$k";
			}
			print OUT "$end5\t\t$k\t\t$line\n";
			OUT->flush();
		}
	}

	close OUT;
}
