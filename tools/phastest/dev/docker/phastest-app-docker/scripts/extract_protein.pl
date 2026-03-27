#!/usr/bin/perl -w

# this program will extract Paul's files at column 'end5' when there
# is 'PHAGE'  or [ANNO] or [HMM-GLOCAL] on that line. After that we will use that number to search
# the prophage's .gbk file of NCBI (<flag>='gbk' or 'faa') and get the GENE position back and that
# linked URL if .gbk file exit. If not, use .faa file. Then go to that URL to extract protein sequence.
#
# input file involved: ../.faa, ../tRNAscan.out, ../tmRNA_aragorn.out
#
# Usage : perl extract_protein.pl  <case number>  <input_file> <output_file> <annotation flag>
use Bio::SeqIO;
use Bio::Seq;
use Cwd;

my $num = $ARGV[0];
my $input_file = $ARGV[1];
my $ptt_file = $ARGV[2];
my $output_file = $ARGV[3];
my $anno_flag = $ARGV[$#ARGV];
my $seq =`cat ../$num.fna`;
$seq =~s/>.*?\n//s;
$seq =~s/[\n\s]//gs;


my %hash_RNA=();
get_hash_RNA(\%hash_RNA);
my %hash_pid=();
my %hash_gocomp=();
my %hash_gofunc=();
my %hash_goproc=();
get_hash_ptt(\%hash_pid, \%hash_gocomp, \%hash_gofunc, \%hash_goproc);
my $faas=get_FAA_info($num);

if (-s $input_file){
	my ($regions, $head_line)=parse_scan_output($input_file, $num, \%hash_RNA, \%hash_pid, \%hash_gocomp, \%hash_gofunc, \%hash_goproc, $faas);
	print_out($regions, $head_line);
}else{
	print STDERR "There is no $input_file \nprogram exit\n";
	exit(-1);
}
exit;

sub get_FAA_info{
	my $num=shift;
	my @faas=();
	my @data=split('>gi', `cat ../$num.faa`);
	foreach my $e (@data){
		next if ($e eq '');
		# |00001|  [DEFINITION  Escherichia coli str. K-12 substr. MG1655 chromosome   PP_00001        gene     343..2799]
		# |00004|  [DEFINITION  Escherichia coli str. K-12 substr. MG1655 chromosome   PP_00004        gene      complement(5310..5537)]
		# |16127998|ref|NP_414545.1| threonine synthase, 3734..5020 [Escherichia coli str. K-12 substr. MG1655]
		# |49175991|ref|YP_025292.1| toxic membrane protein, small, complement(16751..16903) [Escherichia coli str. K-12 substr. MG1655]
		# |1401|ref|SDB45672.1| phage shock protein C (PspC) family protein, 1671931..1673718 [Flavobacteriaceae bacterium MAR_2010_188]
		if ($e =~/\s+\((?:(?!\,).)*\)/s){
			$e =~s/\s+\((?:(?!\,).)*\)/ /sg;
		}
		# |100252|ref|NP_414782.1| CP4-6 prophage; predicted protein, complement(264748..265206) [Escherichia coli str. K-12 substr. MG1655]
		if ($e=~/^\|(\d+)\|.*?(complement\(<*>*\d+\.\.<*>*\d+\)).*?\]/ or $e=~/^\|(\d+)\|.*?\s+(<*>*\d+\.\.<*>*\d+).*?\]/){
			my $f= new FAA();
			$f->{gi}= $1;
			$f->{position}=$2;
			$f->{protein_seq}=$';
			$f->{protein_seq}=~s/[\s\n\W]//gs;
			if ($f->{position}=~/^.*?complement\(<*>*(\d+)\.\.<*>*(\d+)\)/){
				$f->{end5}=$2; 	$f->{end3}=$1;
			}
			elsif($f->{position}=~/^.*?<*>*(\d+)\.\.<*>*(\d+)/){
				$f->{end5}=$1; $f->{end3}=$2;
			}
			push @faas, $f;
        }
    }
	return \@faas;
}

sub get_position{
	my ($end5, $gi, $faas)=@_;

	if (!defined($end5) or !defined($gi)) {
		print STDERR "ERROR: parameters not defined on get_position subroutine.\n";
	}

	foreach my $f (@$faas){
		if ($f->{end5} == $end5 && $f->{gi}==$gi){
			return $f->{position}, $f->{protein_seq};
		}
	}
	print STDERR "ERROR: 5' end and gi not defined from .faa file - $end5, $gi\n";
	return '', '';
}
# get genes from NCBI and output data to extract_result.txt
sub parse_scan_output{
	my ($filename, $num, $hash_RNA, $hash_pid, $hash_gocomp, $hash_gofunc, $hash_goproc, $faas)=@_;
	my $head_line='';
	my $head_flag = 1;
	my $r='';
	my %regions=();
	my $cur_region='';
	my $parse_fail_line_count = 0; # Number of lines that could not be parsed so far and that we printed error messages about.
	open(IN2, $filename) or die "Cannot open $filename";

	while(<IN2>) {
		next if ($_=~/^\s*$/);
		$r='';
		if ( $head_flag ==1){
			# gi|53723370|ref|NC_006348.1| Burkholderia mallei ATCC 23344 chromosome 1, complete sequence [asmbl_id: NC_006348], 3510148, gc%: 68.15%
			$head_line = $_;
			if ($head_line =~/gc\%\:\s*0.00/){
				my $sub_seq = $seq;
				$sub_seq =~s/[ATat]//gs;
				my $p = length($sub_seq)/length($seq);
				$p = int($p *1000) /10;
				$head_line =~s/gc\%\:\s*0.00/gc\%\: $p/;
			}
			# print "$head_line\n";
			$head_flag =0;
			next;
		}
		#region 1 is from
		if ($_=~/region (\d+) is from/){
			$cur_region=$1;
			$regions{$cur_region}=[];
			next;
		}
		elsif ($_=~/BACTERIAL HITS/) {
			$cur_region= (keys %regions) + 1;
			$regions{$cur_region}=[];
			next;
		}

		# 1497588    01402              gi|1402|ref|YP_009839519.1|, TAG = PHAGE_Strept_StarPlatinum_NC_048721, E-VALUE = 5.90e-05
		#                               [ANNO] DnaE-like DNA polymerase III alpha; PP_01402; phage; -
        if ($_=~/^(\d+)\s+(\d+)\s+gi\|(\d+)\|.*TAG\s*=\s*(\S+), E-VALUE\s*=\s*(\S+)/){
            $r= new Virus_hit_record;
			$r->{end5}=$1;
			$r->{local_gi_number}=$2;
			$r->{phage_gi_num}=$3;
			$r->{phage_name}=$4;
			$r->{evalue}=$5;
			$r->{class}='hit';
			$r->{pid}=$hash_pid->{$r->{end5}};
			$r->{go_comp}=$hash_gocomp->{$r->{end5}};
			$r->{go_func}=$hash_gofunc->{$r->{end5}};
			$r->{go_proc}=$hash_goproc->{$r->{end5}};
			($r->{position}, $r->{protein_seq})=get_position($r->{end5},  $r->{local_gi_number}, $faas);
			if (<IN2>=~/^\s\s\s\s\s+\[ANNO\](.*)/){
				$r->{phage_name} .= ":$1";
			}else{
				$r->{phage_name} .= ":";
			}
			push @{$regions{$cur_region}}, $r;
		}
		# 4407841  26990594           ORF0001, TAG = PHAGE_coliph_R73, E-VALUE = 3e-16
		elsif ($_=~/^(\d+)\s+(\d+)\s+(\S+),\s+TAG\s*=\s*(\S+), E-VALUE\s*=\s*(\S+)/){
			$r= new Virus_hit_record;
			$r->{end5}=$1;
			$r->{local_gi_number}=$2;
			$r->{phage_gi_num}='N/A';
			$r->{phage_name}="$4,$3";
			$r->{evalue}=$5;
			$r->{class}='hit';
			$r->{pid}=$hash_pid->{$r->{end5}};
			$r->{go_comp}=$hash_gocomp->{$r->{end5}};
			$r->{go_func}=$hash_gofunc->{$r->{end5}};
			$r->{go_proc}=$hash_goproc->{$r->{end5}};
			($r->{position}, $r->{protein_seq})=get_position($r->{end5},  $r->{local_gi_number}, $faas);
			if (<IN2>=~/^\s\s\s\s\s+\[ANNO\](.*)/){
					$r->{phage_name} .= ":$1";
			}else{
					$r->{phage_name} .= ":";
			}
			push @{$regions{$cur_region}}, $r;
		}
		#2586037  attL_3             GATTTAGGTTCCAGCGGCGCAAGCTGTAAGAGTTCGAGTCTCTTCGTCCGCACCA
		elsif ($_ =~/^(\d+)\s+(attL|attR).*?\s+(.*)/ ){
			$r= new Virus_hit_record;
			$r->{end5}=$1;
			$r->{local_gi_number}='N/A';
			$r->{phage_name}=$2;
			$r->{phage_gi_num}= 'N/A';
			$r->{evalue}= 'N/A';
			$r->{end3}= length($3) + $1 -1;
			$r->{position}=$r->{end5}."..".$r->{end3};
			$r->{protein_seq}=$3;
			$r->{class}='hit';
			push @{$regions{$cur_region}}, $r;
		}
		elsif ($_ =~/^(\d+)\s+(?:tRNA|tmRNA|rRNA)\s+\[ANNO\]\s(.*)/){
			$r= new Virus_hit_record;
			$r->{end5}=$1;
			$r->{class}='hit';
			$r->{phage_name}=$2;
			$r->{phage_gi_num}= 'N/A';
			$r->{evalue}= 'N/A';
			$r->{local_gi_number}='N/A';
			$r->{end3}= $hash_RNA->{$1};
			my $s='';
			if ($r->{end5}>$r->{end3}){
				$r->{position}="complement(".$r->{end3}."..".$r->{end5}.")";
				$s=substr($seq, $r->{end3}-1, $r->{end5} - $r->{end3} +1);
				$s=~tr/ATCG/TAGC/;
				$s=reverse($s);
			}else{
				$r->{position}=$r->{end5}."..".$r->{end3};
				$s=substr($seq, $r->{end5}-1, $r->{end3}-$r->{end5}+1);
			}
			$r->{protein_seq}=$s;
			push @{$regions{$cur_region}}, $r;

		}
		# 1498607    01403              [ANNO] quinone-dependent dihydroorotate dehydrogenase [Paenalcaligenes suwonensis]; E-VALUE = 6.331355e-87; PP_01403; -
		elsif ($_ =~/^(\d+)\s+(\d+)\s+\[ANNO\](.*)/){
			$r= new Virus_hit_record;
			$r->{end5}=$1;
			$r->{local_gi_number}=$2;
			$r->{phage_name}=$3;
			$r->{phage_gi_num}= $2;
			$r->{pid}=$hash_pid->{$r->{end5}};
			$r->{go_comp}=$hash_gocomp->{$r->{end5}};
			$r->{go_func}=$hash_gofunc->{$r->{end5}};
			$r->{go_proc}=$hash_goproc->{$r->{end5}};
			if ($r->{phage_name}=~/E-VALUE = (\S+);/){
				$r->{evalue}=$1;
				$r->{phage_name}=~s/E-VALUE = (\S+);//s;
			}else{
				$r->{evalue}= 'N/A';
			}
			$r->{class}='';
			($r->{position}, $r->{protein_seq})=get_position($r->{end5},  $r->{local_gi_number}, $faas);

			if ($r->{position} ne '' && $r->{protein_seq} ne ''){
				push @{$regions{$cur_region}}, $r ;
			}
		}
		elsif ($_ =~/^END5     FEATNAME/ or $_=~/---------------------------/){
				next;
		}
		elsif ($_=~/\.\.\.\.\.\.\.\.\.\.\.\.\.\.\.\.\.\./ or $_=~/^gi\|/){
				next;
		}
		elsif ($_=~/^There are \d+ regions/){
				next;
		}
		elsif ($_=~/^BACTERIAL HITS/) {
			next;
		}
		else{
			if ($parse_fail_line_count < 10) { # Limit number of lines ending up in log file.
				print STDERR "Cannot parse this line: $_";
				$parse_fail_line_count += 1;
			}
		}

	}
	close IN2;
	return \%regions, $head_line;
}

sub print_out{
	my $regions=shift;
	my $head_line=shift;
	$head_line =~s/\[asmbl_id: \S+\].//;
	if (-e  "../$num.gbk"){
		my ($accession) = `grep '^VERSION' ../$num.gbk` =~ /VERSION\s+(\S+)/;
		if (defined $accession && $accession ne ''){
		    $head_line =~s/ref\|.*?\|/ref\|$accession\|/;
	    }
	}
	# output result
	my $line='';
	open(OUT, ">$output_file") or die "Cannot write $output_file";
	print OUT $head_line ."\n";
	$line = sprintf("%-30s     %-80s     %-15s     %-15s     %-30s     %-30s     %-30s     %s\n", "CDS_POSITION", "BLAST_HIT", "EVALUE", "PID", "GO_COMPONENT", "GO_FUNCTION", "GO_PROCESS", "prophage_PRO_SEQ");
	print OUT $line;
	print OUT "--------------------------------------------------------------------------------------------------".
		"-------------------------------------------------------------------------------------\n";

	my $max_iter = keys %{$regions};
	my @key_array = sort {$a<=>$b} keys %{$regions};

	foreach my $k (@key_array){

		if (($k == $max_iter) and ($anno_flag == 1)) {
			print OUT "\n#### Bacterial ####\n" ;
		}
		else {
			print OUT "\n#### region $k ####\n";
		}

		foreach my $r (@{$regions->{$k}}) {
			$r->{phage_name}=~s/^\s*//s;
			$r->{phage_name}=~s/\s*$//s;
			if ($r->{phage_name}=~/^(attL|attR)/ or
				$r->{phage_name}=~/^(tRNA\-\S+)\s/ or
				$r->{phage_name}=~/^(tmRNA)/ or
				$r->{phage_name}=~/^(\S+ ribosomal RNA)/) {
				$line = sprintf("%-30s     %-80s     %-15s     %-15s     %-30s     %-30s     %-30s     %s", $r->{position}, $r->{phage_name}, $r->{evalue}, "", "", "", "", $r->{protein_seq});
			}else{
				$line = sprintf("%-30s     %-80s     %-15s     %-15s     %-30s     %-30s     %-30s     %s", $r->{position}, $r->{phage_name}, $r->{evalue}, $r->{pid}, $r->{go_comp}, $r->{go_func}, $r->{go_proc}, $r->{protein_seq});
			}
			print OUT $line."\n";
		}

	}
	close OUT;

}

# get tRNA/rRNA info from RNA_output.out file.
sub get_hash_RNA {
	my $hash_RNA = shift;

	open(RNA_IN, "<", "../RNA_output.out") or print STDERR "RNA output not found in jobs directory\n";
	while (<RNA_IN>) {
		if ($_ =~ /^section\s+(\d+)\s+(\d+)\s+/) {
			$hash_RNA->{$1} = $2;
		}
	}
	close RNA_IN;

	if (-e "../$num.gbk"){
		open(GBK_IN, "<", "../$num.gbk") or print STDERR "GBK input not found in jobs directory\n";
		while (<GBK_IN>) {
			if ($_ =~ m/^\s+tRNA\s+<*>*(\d+)\.+<*>*(\d+)/ or $_ =~ m/^\s+tRNA\s+complement\(<*>*(\d+)\.+<*>*(\d+)/){
				$hash_RNA->{$1} = $2;
			}
		}
		close GBK_IN;
	}
}

sub get_hash_ptt {
	my ($hash_pid, $hash_gocomp, $hash_gofunc, $hash_goproc) = @_;

	open(ptt_IN, "<", "../$ptt_file") or print STDERR "Unable to locate .ptt file in the jobs directory\n";
	while (<ptt_IN>) {
		if ($_ =~ /^(\d+)\.\.\d+\s+\+\s+\S+\s+\S+\s+(\S+)\s+\S+\s+\S+\s+\S+\t+(NONE|.*?\;)\t+(NONE|.*?\;)\t+(NONE|.*?\;)/) {
			$hash_pid->{$1} = $2;
			$hash_gocomp->{$1} = $3;
			$hash_gofunc->{$1} = $4;
			$hash_goproc->{$1} = $5;
		}
		elsif ($_ =~ /^\d+\.\.(\d+)\s+\-\s+\S+\s+\S+\s+(\S+)\s+\S+\s+\S+\s+\S+\t+(NONE|.*?\;)\t+(NONE|.*?\;)\t+(NONE|.*?\;)/) {
			$hash_pid->{$1} = $2;
			$hash_gocomp->{$1} = $3;
			$hash_gofunc->{$1} = $4;
			$hash_goproc->{$1} = $5;
		}
	}
	close ptt_IN;
}

package Virus_hit_record;

sub new {
	my $class =shift;
	my $self ={ end5=>'',
		end3=>'',
		position=>'',
		local_gi_number=>'',
		phage_gi_num=>'',
		phage_name=>'',
		evalue=>'',
		protein_seq=>'',
		class=>'',
		pid=>'',
		go_comp=>'',
		go_func=>'',
		go_proc=>''
		 };
	bless $self, $class;
	return $self;
}

package FAA;
sub new {
	my $class = shift;
	$self={ position=>'',
		end5=>'',
		end3=>'',
		gi=>'',
		protein_seq=>''};
	bless $self , $class;
	return $self;
}
