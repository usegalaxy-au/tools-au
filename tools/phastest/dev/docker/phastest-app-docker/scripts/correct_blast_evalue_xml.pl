#!/usr/bin/perl -w

# Correct BLAST e-values, which are skewed due to splitting up the target bacterial
# sequences DB. The correction parameters were derived empirically by David Arndt and Ana
# Marcu, though they do not perform the correction perfectly and are not theoretically
# robust.
# See further https://www.biostars.org/p/65025/ and
# https://www.ncbi.nlm.nih.gov/BLAST/tutorial/Altschul-1.html

use strict;
use XML::Simple;
use Data::Dumper;
use Try::Tiny;

# Stats for bacteria_all_select.db. Obtain these by running count_aa.pl.
my $n = 5178567023; # Number of amino acid residues in entire DB.
my $N = 16246931; # Number of sequences in entire DB.

my $results_dir = $ARGV[0];
my $sequence_filename = $ARGV[1];
my $file_pieces = $ARGV[2];
my $db_pieces = $ARGV[3];

chdir "$results_dir";

my %query_evalues;
my $count;
my $previous_key;
my %hits_hash;
my $hit_hsp_hash;
my @hit_hsp_array;
my %original_hash;
my $bit_score;
my $hsp_score;
my $align_length;
my $hsp_gaps;
my $query_start;
my $query_end;
my $hit_start;
my $hit_end;
my $hsp_qseq;
my $hsp_hseq;
my $hsp_midline;
my $hsp_identity;
my $query_len;
my $correction;
my %hit_info;
my $hit_def;
my $stat_kappa;
my $stat_lambda;
my $query_def;
my %info;
my $hsp_num = 0;
my $have_hash = 0;
my $have_array = 0;
my $hit_num = 0;

my $tabular_output = $sequence_filename . "_blast_out";
open (OUT, ">$tabular_output") or die "Cannot open $tabular_output";

for (my $i = 1; $i<=$file_pieces; $i++){
	for (my $db_part_id = 1; $db_part_id <= $db_pieces; $db_part_id++) {

	my $file = "$sequence_filename\_$i\_$db_part_id\_out";
		
	open(IN, "$file") or die "Cannot open $file";

	while(<IN>) {
		chomp ($_);


		if($_ =~ m/<Iteration_query-ID>(.*)<\/Iteration_query-ID>/) {
		    my $query_id =  $1;
		}
		elsif($_ =~ m/<Iteration_query-def>(.*)<\/Iteration_query-def>/) {
		    $query_def =  $1;
		    my @split_def = split(' ', $query_def);
			$query_def = $split_def[0];

		}

		elsif($_ =~ m/<Iteration_query-len>(.*)<\/Iteration_query-len>/) {
		    $query_len =  $1;

		}

		elsif($_ =~ m/<Hsp_num>(.*)<\/Hsp_num>/){
			$hsp_num = $1;
		}

		elsif($_ =~ m/<Hit_accession>(.*)<\/Hit_accession>/) {
		    $hit_def =  $1;
		}
		elsif($_ =~ m/<Hsp_align-len>(.*)<\/Hsp_align-len>/ && ($hsp_num==1)) {
		    $align_length =  $1;
		}

		elsif($_ =~ m/<Hsp_bit-score>(.*)<\/Hsp_bit-score>/ && ($hsp_num==1)) {
		    $bit_score =  $1;
		}
		elsif($_ =~ m/<Hsp_score>(.*)<\/Hsp_score>/ && ($hsp_num==1)) {
		    $hsp_score =  $1;
		}
		elsif($_ =~ m/<Hsp_gaps>(.*)<\/Hsp_gaps>/ && ($hsp_num==1)) {
		    $hsp_gaps =  $1;
		}
		elsif($_ =~ m/<Hsp_query-from>(.*)<\/Hsp_query-from>/ && ($hsp_num==1)) {
		    $query_start =  $1;
		}

		elsif($_ =~ m/<Hsp_query-to>(.*)<\/Hsp_query-to>/ && ($hsp_num==1)) {
		    $query_end =  $1;
		}
		elsif($_ =~ m/<Hsp_hit-from>(.*)<\/Hsp_hit-from>/ && ($hsp_num==1)) {
		    $hit_start =  $1;
		}
		elsif($_ =~ m/<Hsp_hit-to>(.*)<\/Hsp_hit-to>/ && ($hsp_num==1)) {
		    $hit_end =  $1;
		}
		elsif($_ =~ m/<Hsp_qseq>(.*)<\/Hsp_qseq>/ && ($hsp_num==1)) {
		    $hsp_qseq =  $1;
		}
		elsif($_ =~ m/<Hsp_hseq>(.*)<\/Hsp_hseq>/ && ($hsp_num==1)) {
		    $hsp_hseq =  $1;
		}
		elsif($_ =~ m/<Hsp_midline>(.*)<\/Hsp_midline>/ && ($hsp_num==1)) {
		    $hsp_midline =  $1;
		}
		elsif($_ =~ m/<Hsp_identity>(.*)<\/Hsp_identity>/ && ($hsp_num==1)) {
		    $hsp_identity =  $1;

		}

		elsif($_ =~ m/<Hit_num>(.*)<\/Hit_num>/) {

			for (keys %hit_info) { delete $hit_info{$_};};

			$hit_info{ "hit_def" } = $hit_def;
			$hit_info{ "bit_score" } = $bit_score;
			$hit_info{ "hsp_score" } = $hsp_score;
			$hit_info{ "align_length" } = $align_length;
			$hit_info{ "hsp_gaps" } = $hsp_gaps;
			$hit_info{ "query_start" } = $query_start;
			$hit_info{ "query_end" } = $query_end;
			$hit_info{ "hit_start" } = $hit_start;
			$hit_info{ "hit_end" } = $hit_end;
			$hit_info{ "hsp_qseq" } = $hsp_qseq;
			$hit_info{ "hsp_hseq" } = $hsp_hseq;
			$hit_info{ "hsp_midline" } = $hsp_midline;
			$hit_info{ "hsp_identity" } = $hsp_identity;


			if ($hit_num>0){
		    	$original_hash{ $hit_num } = {%hit_info};
			}


		    $hit_num = $1;

		}

		elsif($_ =~ m/<Statistics_hsp-len>(.*)<\/Statistics_hsp-len>/) {
		    $correction  =  $1;

			if($correction==110){
				$correction = $correction+2;
			}elsif($correction==111){
				$correction = $correction+7;
			}elsif($correction==112){
				$correction = $correction+12;
			}elsif($correction>112){
				$correction = $correction+13;
			}

		}
		elsif($_ =~ m/<Statistics_kappa>(.*)<\/Statistics_kappa>/) {
		    $stat_kappa  =  $1;
		}

		elsif($_ =~ m/<Statistics_lambda>(.*)<\/Statistics_lambda>/) {

			$hit_info{ "hit_def" } = $hit_def;
			$hit_info{ "bit_score" } = $bit_score;
			$hit_info{ "hsp_score" } = $hsp_score;
			$hit_info{ "align_length" } = $align_length;
			$hit_info{ "hsp_gaps" } = $hsp_gaps;
			$hit_info{ "query_start" } = $query_start;
			$hit_info{ "query_end" } = $query_end;
			$hit_info{ "hit_start" } = $hit_start;
			$hit_info{ "hit_end" } = $hit_end;
			$hit_info{ "hsp_qseq" } = $hsp_qseq;
			$hit_info{ "hsp_hseq" } = $hsp_hseq;
			$hit_info{ "hsp_midline" } = $hsp_midline;
			$hit_info{ "hsp_identity" } = $hsp_identity;

			if ($hit_num>0){
		    	$original_hash{ $hit_num } = {%hit_info};
			}

		    $stat_lambda  =  $1;

		    foreach my $key (keys %original_hash){		  
		    
		    	%info = %{$original_hash{$key}};

		    	my $mseq_space_count = () = $info{'hsp_midline'} =~ /\ /g;
		      	my $mseq_plus_count = () = $info{'hsp_midline'} =~ /\+/g;
		      	my $qseq_dash_count = () = $info{'hsp_qseq'} =~ /-/g;
		      	my $hseq_dash_count = () = $info{'hsp_hseq'} =~ /-/g;


		      	my $hit_mismatch = $mseq_space_count + $mseq_plus_count - $qseq_dash_count - $hseq_dash_count;

	            my $perc_identity = (100*$info{'hsp_identity'})/$info{'align_length'};
	            $perc_identity = sprintf "%.3f", $perc_identity;

				my $e_value = $stat_kappa*($query_len-$correction)*($n-($N*$correction))*exp(-$stat_lambda*$info{'hsp_score'});

				my $query_stats = $query_def."\t".$info{'hit_def'}."\t".$perc_identity."\t".$info{'align_length'}."\t".$hit_mismatch."\t".$info{'hsp_gaps'}."\t".$info{'query_start'}."\t".$info{'query_end'}."\t".$info{'hit_start'}."\t".$info{'hit_end'}."\t".$info{'bit_score'};

				$query_evalues{ $query_stats } = $e_value;

			}
			
			for (keys %original_hash) { delete $original_hash{$_};};
			
			$hit_num = 0;	

		     
		}
	}

	close IN;

}
}

$previous_key = '';



foreach my $key (sort keys %query_evalues){

	my @values = split("\t", $key);
	my $split_key = $values[0];

	if ($split_key eq $previous_key){
		$hits_hash{$key} = $query_evalues{$key};
	}else{

		$previous_key = $split_key;
		
		$count = 0;
		foreach my $k (sort { $hits_hash{$a} <=> $hits_hash{$b} || $a cmp + $b } (keys %hits_hash) ){

			if ( $count eq 500 ){
				last;
			}

			my $e_value_sci_not = sprintf("%e", $hits_hash{$k});

			if ($e_value_sci_not=~m/e-04/){
				next;
			}

			my @split_def = split("\t", $k);
			my $hit_bit_score = $split_def[-1];
			my $query_definition = join("\t", @split_def[0..@split_def-2]);
			$hit_bit_score = sprintf "%.1f", $hit_bit_score;

			print OUT $query_definition;
			print OUT "\t";
			print OUT $e_value_sci_not;
			print OUT "\t";
			print OUT $hit_bit_score;
			print OUT "\n";

			$count++;
		}

		for (keys %hits_hash) { delete $hits_hash{$_};};
		$hits_hash{$key} = $query_evalues{$key};

	}

}


close OUT;






