#!/usr/bin/perl
# April 9, 2011 Rah. This script process preannoated gbk inputs.
# This will make PHAST faster to handle preprocessed input cases, because blast only runs on
# identified (by protein names) regions (instead of the entire genome).
#
# 	Main Steps:
#
# 		1. Assess the BLASTed regions to find prophages.
# 		2. Identified integrases and (pre-identified) tRNAs are used to predict att sites.
# 		3. Bacterial protein information is copied from gbk file to identified prophages.
# 		4. Completeness is assigned for each prophage using phage genome information.
# 		5. Predicted prophages are printed in phage finder's format.
#
# Note: additional work will be needed to remove transposons
# example command
#perl phast.pl -g NC_002662/NC_002662.gbk -n NC_002662/NC_002662.fna -a NC_002662/NC_002662.faa -t NC_002662/tRNAscan.out -m NC_002662/tmRNA_aragorn.out -p NC_002662/NC_002662.ptt -b NC_002662/ncbi.out

use strict;
use File::Basename;
use lib "$ENV{PHASTEST_HOME}/lib/perl_modules";

# These modules below are defined in the /lib folder of main PHASTEST folder.
use Gene;
use Dictionary;
use Prophage;
use PhageTable;
use Record;
use DNA;
use Contig;

# server-specific environment variable.
my $PHASTEST_HOME=$ENV{PHASTEST_HOME};

# my $SCAN_LIB = "/var/www/html/phast/current/public";
my $logdir = "$PHASTEST_HOME/log/";
my $dbdir = "$PHASTEST_HOME/DB";

# genbank file alone is sufficient for all operations but current script uses all files.
my $fna = "";
my $trn = "";
my $tmr = "";
my $faa = "";
my $bla = ""; # blast result (ncbi.out), please use "null" if not available
my $ptt = "";
my $gbk = ""; # genbank file
my $ctg = ""; # contig positions file; only given if input consists of concatenated contigs
my $log = $logdir."phast.log"; # log file

# blast parameters:
my $db = "$dbdir/prophage_virus.db";	# blast database
my $usetop = 250;		# max top hits to use

# DBSCAN parameters:
my $eps = 3000;			# distance parameter (see DBSCAN paper)
my $minpts = 4;			# minimal CDS to form a phage
my $hit_known_genome_percentage_threshold= 0.5; # 50% higher or equal is counted as phage region hit
my $prophage_distance_threshold=1000; # join threshold for two close prophage. if lower, join.

# premature prophages joining parameters
my $maxIntDistance = 10000;	# this is the max distance an "noise" integrase can be joined to the nearby prophage (otherwise the integrase will be made into an individual prophage)
my $phageGenomeTable = "$dbdir/vgenome.tbl";
my $maxphage = 150000;		# maximal phage in bps after join

# database and tables
my $virustable = `grep '>' $db`;

# time stamp
my $ProgramStartTime = time;

# debug var
my $debug_int_outputs = 0;
my $debug_p_afterDBSCAN = 0;
my $debug_p_afterJoin = 0;
my $debug_p_afterblast = 0;
my $filter = 1;

# parse arguments
if ($#ARGV == -1){
	&help();
}
for my $i (0 .. $#ARGV){
	if ($ARGV[$i] eq '-h'){
		&help();
	}
	elsif ($ARGV[$i] eq '-g'){
		$gbk = $ARGV[++$i];
	}
	elsif ($ARGV[$i] eq '-n'){
		$fna = $ARGV[++$i];
	}
	elsif ($ARGV[$i] eq '-a'){
		$faa = $ARGV[++$i];
	}
	elsif ($ARGV[$i] eq '-t'){
		$trn = $ARGV[++$i];
	}
	elsif ($ARGV[$i] eq '-m'){
		$tmr = $ARGV[++$i];
	}
	elsif ($ARGV[$i] eq '-b'){
		$bla = $ARGV[++$i];
	}
	elsif ($ARGV[$i] eq '-p'){
		$ptt = $ARGV[++$i];
	}
	elsif ($ARGV[$i] eq '-c'){
		$ctg = $ARGV[++$i];
	}
	elsif ($ARGV[$i] eq '-use'){
		$usetop = $ARGV[++$i];
	}
	elsif ($ARGV[$i] eq '-Deps' || $ARGV[$i] eq '-gap'){
		$eps = $ARGV[++$i];
	}
	elsif ($ARGV[$i] eq '-Dpts'){
		$minpts = $ARGV[++$i];
	}

	# Debug parameters:
	elsif ($ARGV[$i] eq '-dDBSCAN'){
		$debug_p_afterDBSCAN = 1;
	}
	elsif ($ARGV[$i] eq '-djoin'){
		$debug_p_afterJoin = 1;
	}
	elsif ($ARGV[$i] eq '-dblast'){
		$debug_p_afterblast = 1;
	}
	elsif ($ARGV[$i] eq '-rmfilter'){
		$filter = 0;
	}
	else{
#		die "unknown flag '$ARGV[$i] at position' $i";
	}
}

# dynamic data
my $sequence = new DNA($fna);
my $genomehead = ''; 	# head of sorted Gene list
my $genometail = ''; 	# tail of sorted Gene list
my $prophagehead = '';		# head of sorted prophage region list
my %localgihash = ();	# hash table keyed by Gene local gi number (exclude RNA)
my %starthash = ();		# hash table keyed by Gene start index (include RNA)


# local functions
sub help {
	print "PHASTER's scan.pl (http://phast.ca)\n";
	print "Originally written for PHAST by Rah Zhou (email: youz\@ualberta.ca)\n";
	print "Adapted for PHASTEST by Scott Han (email: shhan\@ualberta.ca)\n";
	print "flags:";
	print "  -h                 print this help page\n";
	print "  -g [file]          Genbak file (.gbk)\n";
	print "  -n [file]          DNA sequence file (.fna)\n";
	print "  -a [file]          amino acid (protein) sequence file (.faa)\n";
	print "  -t [file]          tRNAscan-SE output file\n";
	print "  -m [file]          Aragorn output file\n";
	print "  -b [file]          NCBI blast result (ncbi.out, tuple format -8)\n";
	print "  -p [file]          genome information file (.ptt)\n";
	print "  -c [file]          parse contig positions from the given file (for sequence\n";
	print "                     input that consists of concatenated contigs)\n";
	print "  -L                 run local BLAST (default is to not do so)\n";
	print "  -use		        specify the top number of blast results for analysis\n";
	print "  -Beva              specify blast evalue\n";
	print "  -Deps, -gap        specify eps parameter of DBSCAN clustering algorithm\n";
	print "  -Dpts              specify minimal number cluster size of DBSCAN clustering algorithm\n";
	print "In order to run either Genbank file or .ptt file has to be given.\nIf Genbank file is given annotations will be used for identifying phage genes in the genome.\n";
	exit;
}

# insert a Gene to this sorted list. This could be expensive because the list can be long
sub insertGene {
	my $gene = shift;
	my $cursor;
	if ($genomehead eq ''){
		$genomehead = $gene;
		$genometail = $gene;
		return 0;
	}
	elsif ($gene->getStart() <= $genomehead->getStart()){
		$gene->setNext($genomehead);
		$genomehead->setPrevious($gene);
		$genomehead = $gene;
	}
	elsif ($gene->getStart() >= $genometail->getStart()){
		$gene->setPrevious($genometail);
		$genometail->setNext($gene);
		$genometail = $gene;
	}
	elsif (abs($gene->getStart() - $genomehead->getStart()) < abs($gene->getStart() - $genometail->getStart())){
		for ($cursor = $genomehead; $cursor->getStart() < $gene->getStart(); $cursor = $cursor->next()){}
		$gene->setNext($cursor);
		$gene->setPrevious($cursor->previous());
		$cursor->previous()->setNext($gene);
		$cursor->setPrevious($gene);
	}
	else{
		for ($cursor = $genometail; $cursor->getStart() > $gene->getStart(); $cursor = $cursor->previous()){}
		$gene->setPrevious($cursor);
		$gene->setNext($cursor->next());
		$cursor->next()->setPrevious($gene);
		$cursor->setNext($gene);
	}
	
	# Record contig to which the gene belongs
	my $start = $gene->getStart();
	my $end = $gene->getEnd();
	my $contig_id = $sequence->getContigIdForPos($start);
	my $contig_id_end = $sequence->getContigIdForPos($end);
	if ($contig_id == $contig_id_end) {
		$gene->setContigId($contig_id);
	} else {
		# If a gene spans from one contig to another (hopefully this will never happen!), set
		# the contig id to -1 so that the gene will be completely ignored.
		$gene->setContigId(-1);
		print STDERR "Warning: gene at $start to $end overlaps contig boundary!\n";
	}
}

sub findCoverlapRNA {
	my ($start, $end) = @_;
	my $cursor;
	for ($cursor = $genomehead; $cursor ne ''; $cursor = $cursor->next()){
		if ($cursor->isRNA()){
			if ($cursor->getEnd() >= $start  and $cursor->getStart() <= $end){
				return $cursor;
			}
		}
		elsif ($cursor->getStart() > $end){
			last;
		}
	}
	return '';
}

sub findGeneByLocalGI {
	my $targetGI = shift;
	return $localgihash{$targetGI};
}

sub findGeneByStart {
	my $targetStart = shift;
	return $starthash{$targetStart};
}

# genbank file alone is sufficient for all operations but current script uses all files
# future work will be to write this function to use gbk file only to reduce complexity of the code
sub buildGenome{
	
	# parse contig positions file (if given)
	if ($ctg ne "") {
		$sequence->loadContigs($ctg);
	}
	
	# parse .ptt file (assume proteins are sorted by index)
	open (R, $ptt) or die "cannot open ptt file $ptt, ptt is mandatory";
	while (my $line = <R>){
		# 570116..570667	+	183	00536	ybcL	PP_00536	b0545	-	NONE	NONE	NONE	"N/A"	DLP12 prophage; secreted protein, UPF0098 family [NP_415077.1]
		if ($line =~m/^(\d+)\.\.(\d+)\t(.*?)\t.*?\t(.*?)\t.*?\t(.*?)\t.*\"\s+(.*?)\s+\[/){
			my $gene = new Gene($4, $1, $2, $3, $6, 'p', $5);
			&insertGene($gene);
			$localgihash{$4} = $gene;
			$starthash{$1} = $gene;
		}
		# 2..1021	+	339	00001	-	PP_00001	-	-	NONE	NONE	NONE	"Predicted gene region."	-
		elsif ($line =~m/^(\d+)\.\.(\d+)\t(.*?)\t.*?\t(.*?)\t(.*?)\t(.*?)\t/){
			my $gene = new Gene($4, $1, $2, $3, $6, 'p', $5);
			&insertGene($gene);
			$localgihash{$4} = $gene;
			$starthash{$1} = $gene;
		}
	}
	close (R);
	# parser .gbk file to insert tRNA (if exists)
	if (-e $gbk){
		open (R, $gbk) or die "cannot read genbank file $gbk (hardware)";
		while (my $line = <R>){
			my $strand = '';
			my $start = '';
			my $end = '';
			my $product = '';
			if ($line=~m/^\s+tRNA\s+<*>*(\d+)\.+<*>*(\d+)/){
				$strand = '+';
				($start, $end) = ($1, $2);
			}
			elsif ($line=~m/^\s+tRNA\s+complement\(<*>*(\d+)\.+<*>*(\d+)/){
				$strand = '-';
				($start, $end) = ($2, $1);
			}
			if ($start ne ''){
				while ($line = <R>){ # looking for tRNA product
					if ($line=~m/^\s\s\s\s\s\w/){last;} # move on ifhit the next feature (assume no consective tRNAs)
						if ($line=~m/^\s+\/product="(.+)"/){
								$product = $1;
								last;
						}
					}
				#print "$start, $end, $strand, $product, 'r'\n";
				my $gene = new Gene('', $start, $end, $strand, $product, 't'); # local gi, start, end, strand, product and type
				&insertGene($gene);
				$starthash{$start} = $gene;
			}
		}
		close (R);
	}
	#print "start parse tRNA file\n";
	if (-e $trn){
		open (R, $trn) or die "cannot read $trn which should be the tRNA file (hardware)";
		while (my $line = <R>){
			# Name                        	tRNA #	Begin  	End    	Type	Codon	Begin	End		Score
			# gi|16271976|ref|NC_000907.1| 	1		47152  	47241  	Ser		TGA		0		0		69.75
			if ($line =~m/^gi/){
				my @tokens = split (/\t/, $line);
				if ($#tokens < 8){
					print STDERR "error: tRNA file line: $line\n";
				}
				my ($strand, $start, $end);
				if ($tokens[2] < $tokens[3]){
					$strand = '+';
					($start, $end) = ($tokens[2], $tokens[3]);
				}
				else{
					$strand = '-';
					($start, $end) = ($tokens[3], $tokens[2]);
				}
				# local gi, start, end, strand, product and type
				my $tRNAgene = new Gene('', $start, $end, $strand, "tRNA-$tokens[4]", 't');
				my $existRNA =  &findGeneByStart($start);
				if ($existRNA eq ''){
					$existRNA = &findCoverlapRNA($start, $end);
				}
				if ($existRNA eq ''){
					&insertGene($tRNAgene);
				}
			}
		}
		close (R);
	}
	#print "start parse tmRNA\n";
	if (-e $tmr){
		open (R, $tmr) or die "cannot read $trn which should be the tmRNA file (hardware)";
		while (my $line = <R>){
			# seems can either be "Location c[1357564,1357929]" or "Location [1357564,1357929]"
			my ($strand, $start, $end);
			if ($line =~m/^Location\s*\[(\d+),(\d+)\]/){
				$strand = '+';
				$start = $1;
				$end = $2;
			}
			elsif ($line =~m/^Location\s*c\[(\d+),(\d+)\]/){
				$strand = '-';
				$start = $2;
				$end = $1;
			}
			else{
				next;
			}
			# local gi, start, end, strand, product and type
			my $tRNAgene = new Gene('', $start, $end, $strand, "tmRNA", 'tm');
			my $existRNA =  &findGeneByStart($start);
			if ($existRNA eq ''){
				$existRNA = &findCoverlapRNA($start, $end);
			}
			if ($existRNA eq ''){
				&insertGene($tRNAgene);
			}
		}
		close (R);
	}
	#print "start parse (ncbi.out) blast file\n";
	if (-e $bla){
		open (R, $bla) or die "cannot read $bla, which is the viral database blast result (hardware)";
		my %blast = (); # store results
		my @all = <R>;
		close (R);
		foreach(@all){
			my @tokens = split(/\t/, $_);
			if ($tokens[0]=~m/^gi\|(\d+)/){
				my $querygi = $1;
        		if ($tokens[1]=~m/([A-Z]+\_\d+\.\d+)/ || $tokens[1]=~m/([A-Z]+\d+\.\d+)/){
					my $ref = $1;

					my $gi = '';
					if ($tokens[1]=~m/gi\|(\d+)/){
						$gi = $1;
					}

					my $sp = '';
					if ($tokens[1]=~m/(\S+)\-/){
						$sp = $1;
					}

					# local gi, species, definition, accession no., evalue.
					my $record = new Record($querygi, $sp, "", $ref, $tokens[10]);

					if (defined $blast{$querygi}){
						my $array =  $blast{$querygi};
						if ($#$array+1 < $usetop){
							$$array[$#$array+1] = $record;
						}
					}
					else{
						my @array = ();
						push (@array, $record);
						$blast{$querygi} = \@array;
					}
				}
				else{
					print STDERR "BLAST output does not contain accession number: $_\n";
				}
			}
		}

		while (my ($k, $v) = each %blast){
			my $target = &findGeneByLocalGI($k);
			if ($target ne ''){
				$target->setBLASTresult($v);
			}
			else{
				print STDERR  "error: blast returned unexpected results for local GI $k\n";
				next;
			}
		}
	}
}

# print the genome list (protein and rRNA) for debug
sub printGenome {
	my ($hits) = @_;
	for (my $cursor = $genomehead; $cursor ne ''; $cursor = $cursor->next()){
		$cursor->printInfo($hits);
	} 
}

# print the prophage list for debug
sub printProphage {
	my ($hits) = @_;
	for (my $cursor = $prophagehead; $cursor ne ''; $cursor = $cursor->next()){
		$cursor->printInfo($hits);
	}
}

# sub to annotate the blast result (because blast result has no annotation)
sub addAnnotation {
	my %hash = ();
	foreach my $line (split("\n", $virustable)){
		chomp ($line);
		#>PROPHAGE_Xantho_306-gi|21243357|ref|NP_642939.1| phage-related integrase [Xanthomonas axonopodis pv. citri str. 306]
		if ($line=~/ref\|(.*?)\|\s*(.*)/){
			$hash{$1} = $2;
		}
	}
	for (my $cursor = $genomehead; $cursor ne ''; $cursor = $cursor->next()){
		my $hits = $cursor->getBLASTresult();
		if ($hits ne '' and $hits ne "keyword"){
			foreach (@$hits){
				if (defined $hash{$_->getRefAcc()}){
					$_->setDefinition($hash{$_->getRefAcc()});
				}
				else{
					$_->setDefinition("ERROR IN DATABASE: CANNOT LINK THIS PROTEIN");
					print STDERR "ERROR: virus database has no record for accession number: ", $_->getRefAcc(), "\n";
				}
			}
		}
	}
}

# prophage list
sub insertProphage {
	my $prophage = shift;

	# No entry in the linked list.
	if ($prophagehead eq ''){
		$prophagehead = $prophage;
	}

	# New prophage's start position is less than current $prophagehead's start position.
	elsif ($prophage->getHead()->getStart() < $prophagehead->getHead()->getStart()){
		$prophage->setNext($prophagehead);
		$prophagehead->setPrevious($prophage);
		$prophagehead = $prophage;
	}
	else{	

		# If the $prophagehead's start position is less than the new prophage region's start position, iterate through linked list.
		for (my $cursor = $prophagehead; $cursor ne ''; $cursor = $cursor->next()){

			# At the end of the linked list; append new prophage at the end of the linked list.
			if ($cursor->next() eq ''){
				$prophage->setPrevious($cursor);
				$cursor->setNext($prophage);
				last;
			}

			# Found a position to insert new prophage while iterating through $prophagehead linked list. 
			elsif ($prophage->getHead()->getStart() < $cursor->next()->getHead()->getStart()){
				$prophage->setNext($cursor->next());
				$prophage->setPrevious($cursor);
				$cursor->next()->setPrevious($prophage);
				$cursor->setNext($prophage);
				last;
			}
		}
	}
}

# DBSCAN algorithms
#DBSCAN(D, eps, MinPts)
#   C = 0
#   for each unvisited point P in dataset D
#      mark P as visited
#      N = getNeighbors (P, eps)
#      if sizeof(N) < MinPts
#         mark P as NOISE
#      else
#         C = next cluster
#         expandCluster(P, N, C, eps, MinPts)
#          
#expandCluster(P, N, C, eps, MinPts)
#   add P to cluster C
#   for each point P' in N 
#      if P' is not visited
#         mark P' as visited
#         N' = getNeighbors(P', eps)
#         if sizeof(N') >= MinPts
#            N = N joined with N'
#      if P' is not yet member of any cluster
#         add P' to cluster C
#end
sub DBSCAN_main {
	my @noise = ();

	# Iterate through $genomehead linked list.
	for (my $unvisited = $genomehead; $unvisited ne ''; $unvisited = $unvisited->next()){

		# If an entry in the $genomehead isn't visited and isn't an RNA region...
		if (!$unvisited->isRNA() and $unvisited->getBLASTresult() ne '' and $unvisited->isVisited() == 0){

			# Set that $genomehead as visited,
			$unvisited->setVisited(1);
			my $neighbors = &DBSCAN_neighbors($unvisited);

			# If no. neighbors < minimum CDS threshold, add new phage to the noise.
			if ($#$neighbors < $minpts){
				push (@noise, $unvisited);
			}

			# Else, create new prophage and insert it until neighbor is over minimum CDS threshold.
			else{
				my $prophage = new Prophage();
				&DBSCAN_expand($unvisited, $neighbors, $prophage);
				&insertProphage($prophage);
			}
		}
	}
	
	# salvage any integrase from noise
	# there're usually integrase in noise array, we try to add them to closest
	# prophages
	foreach (@noise){
		if (&isPhageGene($_) == 0 and $_->isIntegrase() == 1){
						
			# find the previous and next phage neighboring $_
			my $pre = ''; # closest upstream prophage region
			my $nex = ''; # closest downstream prophage region

			for ($nex = $prophagehead; $nex ne ''; $nex = $nex->next()){
				if ($nex->getHead()->getStart()>$_->getStart()){
					$pre = $nex->previous();
					last;
				}
			}
			
			if ($ctg ne "") {
				# do not count prophage regions on neighboring concatenated contigs
				if ($nex ne '' and $nex->getHead()->getContigId() != $_->getContigId()) {
					print STDERR "Not counting neighboring phage region that appears on a downstream contig!\n"; # This is not an error, just information.
					$nex = '';
				}
				if ($pre ne '' and $pre->getTail()->getContigId() != $_->getContigId()) {
					print STDERR "Not counting neighboring phage region that appears on an upstream contig!\n"; # This is not an error, just information.
					$pre = '';
				}
			}
			
			if ($prophagehead eq ''){
				# no prophage found yet
			}
			elsif ($pre eq '' and $nex eq ''){
				# no neighboring prophages found
			}
			elsif ($pre eq '' and $nex ne ''){
				# There is a downstream phage but not an upstream one.
				# If closest downstream prophage region is close enough, add $_ to it:
				if ($nex->getHead()->getStart - $_->getEnd() < $maxIntDistance){
					$nex->insert($_);
#					print "add to the first phage\n";
					next;
				}
			}
			elsif ($pre ne '' and $nex eq ''){
				# There is an upstream phage but not a downstream one.
				# if closest upstream prophage region is close enough, add $_ to it:
				if ($_->getStart() - $pre->getTail()->getEnd() < $maxIntDistance){
					$pre->insert($_);
#					print "add to the last phage\n";
					next;
				}
			}
			else{
				# There are both upstream and downstream phages.
				
				if ($nex->getHead()->getStart - $_->getEnd() < $maxIntDistance 
				and $_->getStart() - $pre->getTail()->getEnd() > $maxIntDistance){
					$nex->insert($_);
#					print "add to the right phage because left is out of range\n";
					next;
				}
				elsif ($nex->getHead()->getStart - $_->getEnd() > $maxIntDistance 
				and $_->getStart() - $pre->getTail()->getEnd() < $maxIntDistance){
					$pre->insert($_);
#					print "add to the left phage because right is out of range\n";
					next;
				}
				elsif ($nex->getHead()->getStart - $_->getEnd() < $maxIntDistance 
				and $_->getStart() - $pre->getTail()->getEnd() < $maxIntDistance){
					if ($pre->hasIntegrase() == 1 and $nex->hasIntegrase() == 0){
						$nex->insert($_);
#						print "add to the right phage because left has int but not right\n";
						next;
					}
					elsif ($pre->hasIntegrase() == 0 and $nex->hasIntegrase() == 1){
						$pre->insert($_);
#						print "add to the left phage because right has int but not left\n";
						next;
					}
					else{
						if ($_->getStart() - $pre->getTail()->getEnd() < $nex->getHead()->getStart() - $_->getEnd()){
							$pre->insert($_);
#							print "add to the left phage because it's closer\n";
							next;
						}
						else{
							$nex->insert($_);
#							print "add to the right phage because it's closer\n";
							next;
						}
					}
				}
			}
		}
	}
}

sub DBSCAN_neighbors {
	my $self = shift;
	my @neighbors = ();
	for (my $cursor = $self->previous(); $cursor ne '' and $self->getStart() - $cursor->getEnd() < $eps 
		and ($ctg eq "" or ($self->getContigId() == $cursor->getContigId())); $cursor = $cursor->previous()){

		if ($cursor->getBLASTresult() ne ''){
			push (@neighbors, $cursor);
		}
	}
	for (my $cursor = $self->next(); $cursor ne '' and $cursor->getStart() - $self->getEnd() < $eps 
		and ($ctg eq "" or ($self->getContigId() == $cursor->getContigId())); $cursor = $cursor->next()){

		if ($cursor->getBLASTresult() ne ''){
			push (@neighbors, $cursor);
		}
	}
	return \@neighbors;
}

sub DBSCAN_expand {
	my ($p, $N, $c) = @_; # for meanings of names, see pseudocode
	$c->insert($p);
	# Initial set of neighbors will only be within ~$eps bases of the seed gene. But here
	# we search for neighbors of these neighbors recursively.
	for (my $i = 0; $i <= $#$N; $i++){ # Value of $#$N will increase as elements added to N.
		if ($$N[$i]->isVisited == 0){
			$$N[$i]->setVisited(1);
			my $M = &DBSCAN_neighbors($$N[$i]);
			if ($#$M >= $minpts){
				foreach (@$M){
					push (@$N, $_); # Add new neighbors. These new neighbors will be evaluated themselves in the main for loop.
				}
			}
		}
		if (&isPhageGene($$N[$i]) == 0){ # Check if the gene has already been added to a prophage. (This check filters out the duplicates created just above.)
			# Gene was not in a prophage already, so add it.
			$c->insert($$N[$i]);
		}
	}
}

sub structNode {
	my %phage = ();
	my $self = {
		_phage => \%phage,
		_score => 0,
		_penalty => 0,
		_next => '',
		_percentage_max=>-1,
		_hit_count_max=>-1,
		_origin_length_max=>-1,
		_NC_max=>'',
		_NC_acc=>'',
		_NC_PHAGE=>'',
		_LOC => 0
	};
	return $self;
}

# Notes by David Arndt:
# To determine which prophage regions should be joined, this subroutine assesses all
# possible combinations of joining 2 or more neighboring prophage regions. Consider, for
# example, 5 initial phage regions A through E. The @toptable will have the structure
# shown below:
#
#       -----AAAAAAAAA---BBBBB-----CCCCCCCCCC--------------------DDDDDDDD----EEEEEE-----
# 
# toptable:      A ------> AB --------> ABC
#                           B -------->  BC
#                                         C
#                                                                    D ------> DE
#                                                                               E
#
# In this example, C and D are too far apart and so cannot be joined. The algorithm
# assesses scores for each prophage region on its own, as well as combining A and B
# together (AB), combining A and B and C (ABC), combining B and C (BC), etc. The primary
# nodes in @toptable are on the diagonal (A, B, C, D, E), which are at the beginning
# of linked lists as shown by the arrows above. Each possible joined prophage is penalized
# based on the sum of the gaps between its constituent prophages.
sub joinProphage {
	# join prophages if they are found to have the same phage genome
	my $table = new PhageTable($phageGenomeTable, $filter);
	# check all possible combination of prophages region for better results
#	printProphage(1) if $debug_int_outputs;
	my $t=0;
	for (my $px = $prophagehead; $px ne ''; $px = $px->next()){
		$t++;
		print "position $t:".$px->getHead()->getStart(). " ". $px->getTail()->getEnd()."\n" if $debug_int_outputs;
	}
	my @toptable = ();
	my $cou=0;
	for (my $px = $prophagehead; $px ne ''; $px = $px->next()){
		my $penalty = 0;
		my $headnode = '';
		$cou++;
		my $count=0;
		for (my $py = $px; $py ne '' and $py->getTail()->getEnd() - $px->getHead()->getStart() < $maxphage and ($ctg eq "" or ($px->getHead()->getContigId() == $py->getTail()->getContigId())); $py = $py->next()){
			my $node = &structNode();
			if ($py == $px){
				$penalty = 0;
				$headnode = $node;
				push (@toptable, $headnode);
				$table->clear();
				$node->{_LOC} = $py->getHead->getStart();
				print "HEAD at ($py)",$py->getHead()->getStart(), "-", $py->getTail()->getEnd()," (P:$penalty)\n" if $debug_int_outputs;
				$count++;
			}
			else{
				$headnode->{_next} = $node;
				$headnode = $node;
				for (my $cur = $px; $cur != $py; $cur = $cur->next()){
					$node->{_phage}->{$cur} = 1;
				}
				$penalty += ($py->getHead()->getStart() - $py->previous()->getTail()->getEnd()) * 100;
				print "    extend at ",$py->getHead()->getStart(), "-", $py->getTail()->getEnd()," (P:$penalty)\n" if $debug_int_outputs;
				$count++;
			}
			$table->assessprophage($py, $cou, $count);
				# Each call to assessprophage adds to and modifies the tallies of the various
				# stats of $table (PhageTable object), essentially "growing" the prophage region
				# it represents by adding to it the prophage region $py.
			$node->{_phage}->{$py} = $py;
			($node->{_score}, $node->{_percentage_max}, $node->{_hit_count_max}, $node->{_origin_length_max}, $node->{_NC_max}, $node->{_NC_PHAGE}) = $table->evaluate(1000000, $penalty, $maxphage);
			$py->set_percentage_max($node->{_percentage_max});
			$py->set_hit_count_max($node->{_hit_count_max}); 
			$py->set_origin_length_max($node->{_origin_length_max});
			$py->set_NC_max($node->{_NC_max}); 
			$py->set_NC_PHAGE($node->{_NC_PHAGE});
			$node->{_penalty} = $penalty;
			if ($debug_int_outputs) {
				if ($px == $py){
					print "START: ", $px->getHead()->getStart(),"\n";
					print $table->printParts();
					print ">>>", $py->getHead()->getStart(),"		score = $node->{_score}\n";
					print "			percentage = $node->{_percentage_max}\n";
					print "         CDS = ", $py->getNumberOfCDS(), "\n";
				}
				else {
					print "			score = $node->{_score}\n";
					print "			percentage = $node->{_percentage_max}\n";
					print "         CDS = ", $py->getNumberOfCDS(), "\n";
				}
			}
		}
	}
	# pick-up best prophages
	my @best = ();
	my %picked = ();

	my $m=0;
	while (1){
		$m++;
		my $p = 0;
		my $bestnode = &structNode();	# a node with 0 score
		my $c=0;
		my $best_r=-1;
		my $best_n=-1;
		foreach (@toptable){
			$c++;
			my $n=0;
			for (my $node = $_; $node ne ''; $node = $node->{_next}){
				$n++;
				my $removed = 0;
				while (my ($phage, $v) = each %{$node->{_phage}}){
					if (defined $picked{$phage}){
						$removed = 1;
					}
				}
				if ($removed == 1){
					last;
				}
				elsif ($node->{_score} > $bestnode->{_score}){
					$bestnode = $node;
					$best_n=$n;
					$best_r=$c;
				}
				$p++;
			}
		}
		
		if ($bestnode->{_score} >= 1000000 - 10000){
			push (@best, $bestnode);
			my @py = keys %{$bestnode->{_phage}};
			while (my ($phage, $v) = each %{$bestnode->{_phage}}){
				if (defined $picked{$phage}){print STDERR "$phage: reached unexpected situation\n";}
				$picked{$phage} = $bestnode;
			}
		}
		else{
			last;
		}
	}
	foreach my $node (@toptable){
		if ( $node->{_percentage_max} >= $hit_known_genome_percentage_threshold && $node->{_hit_count_max}>=$minpts){
			my $flag = 0;
			foreach my $d (@best){
				$flag =1 if ($d == $node);
			}
			push (@best, $node) if ($flag ==0);	
		}
	}

	my $newhead = '';
	foreach (@best){
		my $newphage = new Prophage();
		while (my ($phage, $v) = each %{$_->{_phage}}){
			my $ptr;
			# put the class reference to a hash and take it back. Perl won't recognize it, has to do
			# this trick to find it by value.
			for ($ptr = $prophagehead; $ptr ne ''; $ptr = $ptr->next()){
				if ($ptr eq $phage){
					last;
				}
			}
		 	$newphage->set_percentage_max($ptr->get_percentage_max);
			$newphage->set_hit_count_max($ptr->get_hit_count_max);
			$newphage->set_origin_length_max($ptr->get_origin_length_max);
			$newphage->set_NC_max($ptr->get_NC_max);
			$newphage->set_NC_PHAGE($ptr->get_NC_PHAGE);
			for (my $gene = $ptr->getHead(); $gene ne ''; $gene = $gene->next()){
				$newphage->insert($gene);
				if ($gene == $ptr->getTail()){
					last;
				}
			}
		}
		if ($newhead eq ''){
			$newhead = $newphage;
		}
		else{
			$newphage->setNext($newhead);
			$newhead->setPrevious($newphage);
			$newhead = $newphage;
		}
	}

	#now join 2 close phages together
	for (my $r = $newhead; $r ne ''; $r=$r->next()){
		next if ($r == $newhead);
		my $start = $r->getHead->getStart;
		my $found_p='';

		for (my $p = $newhead; $p ne ''; $p=$p->next()){
			if ($p == $r) {
				next;
			}
			my $end = $p->getTail->getEnd;
			if (abs($start-$end) < $prophage_distance_threshold) {
				if ($ctg eq "" or ($r->getHead()->getContigId() == $p->getTail()->getContigId())) {
					$found_p=$p;
					last;
				}
			}
		}
		if ($found_p ne ''){
			for (my $gene = $r->getHead(); $gene ne ''; $gene = $gene->next()){
				$found_p->insert($gene);
				if ($gene == $r->getTail()){
					last;
				}
			}
			#now the prophage r goes to found_p
			$r->previous->setNext($r->next);
			# Jack debugged here, add if condition. Apr 6, 2016
			$r->next->setPrevious($r->previous) if($r->next ne '');
		}	
	}
	# sort $prophagehead and kill the redundant
	if ($newhead ne ''){
    	my $prophage_array = sort_kill_redundant($newhead);
		$prophagehead = '';
		foreach my $toAdd (@$prophage_array){
			$toAdd->setNext('');
        	$toAdd->setPrevious('');
			&insertProphage($toAdd);
		}
	}
	# Reset prophagehead in case DBSCAN detect no prophage region at all
	elsif ($newhead eq '') {
		$prophagehead = '';
	}

	for (my $cursor = $prophagehead; $cursor ne ''; $cursor = $cursor->next()){
		$table->clear();
		$table->assessprophage($cursor, -1, -1);
		my ($score, $percentage_max, $hit_count_max, $origin_length_max, $NC_max, $NC_PHAGE) = $table->evaluate(1000000, 0, $maxphage);
		$cursor->set_percentage_max($percentage_max);
        $cursor->set_hit_count_max($hit_count_max);
        $cursor->set_origin_length_max($origin_length_max);
        $cursor->set_NC_max($NC_max);
		$cursor->set_NC_PHAGE($NC_PHAGE);
		$cursor->setCompleteness($table->completeness());
	}
}
# sort $prophagehead and kill redundant prophages in the list
sub sort_kill_redundant{
	my $newhead = shift;

	my @prophage_array=();
	for (my $r = $newhead; $r ne ''; $r=$r->next()){
		push @prophage_array, $r;
	}
	@prophage_array = sort {$b->getHeadTailSize() <=> $a->getHeadTailSize()} @prophage_array; # sort phage regions from longest to shortest

	for (my $i =1; $i <= $#prophage_array; $i++) {
		my $cur=$prophage_array[$i];

		for (my $j =0; $j < $i; $j++) {
			my $pre=$prophage_array[$j];

			if ($pre->getHead->getStart <= $cur->getHead->getStart && $pre->getTail->getEnd >= $cur->getTail->getEnd){
				# cur is a subset of or identical to pre
				splice @prophage_array, $i, 1;
				$i--;
				last;
			}
		}

	}
	return \@prophage_array;
}
# attachment site
sub searchAttachmentSite {
	for (my $cur = $prophagehead; $cur ne ''; $cur = $cur->next()){
		$sequence->findAttachmentSite($cur); # this also sets att in prophage
		$cur->calculateGC($sequence);	# add GC content information (after p5, p3 determinated)
	}
}

# subs to handle prophage list

# Return whether given gene is already included in a prospective prophage.
sub isPhageGene {
	my $gene = shift;
	for (my $cursor = $prophagehead; $cursor ne ''; $cursor = $cursor->next()){
		if ($cursor->isInclude($gene)){
			return 1;
		}
	}
	return 0;
}

# print to STDOUT output in Phage Finder's format
sub printoutput {
	open (W, ">>$log") or die "cannot write to log file $log";
	my $case = $fna; $case = basename($fna); $case =~s/\.fna//;
	print W "Case: $case\n";
	# header:
	my $asml = "NC_000000";
	if ($faa =~m/(NC_\d+)/){
		$asml = $1;
	}
	print W "START:$asml:$case\n";
	my $pindex = 1;
	open(OUT99, ">region_PHAGEs.txt") or die "Cannot write region_PHAGEs.txt";
	my $header_line = $sequence->getDefinition();
	$header_line .= " [asmbl_id: $asml].";
	$header_line .= $sequence->getSize() . ", ";
	$header_line .= sprintf("gc\%: %5.2f\%\n", 100.0*$sequence->getGlobalGC()/$sequence->getSize());

	print $header_line;
	for (my $p = $prophagehead; $p ne ''; $p = $p->next(), $pindex++){
		print "Medium degenerate region $pindex is from ", $p->get5end(),
		" to ", $p->get3end()," and is ", $p->getSize()," bp in size, ",
		sprintf("gc\%: %5.2f\%", $p->calculateGC($sequence)), ".", $p->getCompleteness(),"\n";
		$p->printPhagefinderResult();
		print OUT99 "$pindex\t".$p->get_NC_PHAGE()."\n";
		print W "PHAGE:$pindex:", $p->get5end(),":", $p->get3end(),"\n";
	}
	print W "END:$asml:$case:", time - $ProgramStartTime,"\n";
	close W;
	close OUT99;

	my $size = $sequence->{_size};
	print sprintf ("There are %d regions between 10 and 18 Kb and summing 26486 bp of sequence ( 1.45\% of the genome)\n", $pindex-1);
}

##########  main program ###########

# reusable variables
my ($cursor, $cursor1, $cursor2, $i);

&buildGenome(); # load input file to make the genome list

# blast has been pre-performed for all CDS, only need to identify phage by keywords in genbank file
# identify prophages by names in genbank file
# step 1 and 2 (done by read blast result). identify all phast regions by keywords:
for ($cursor = $genomehead; $cursor ne ''; $cursor = $cursor->next()){
	if ($cursor->isRNA() == 0 and $cursor->getBLASTresult() eq '' and &strictRelated($cursor->getProduct()) == 1){ # sub in Dictionary.pm
		$cursor->setRelationToPhage(1);
		if ($cursor->getBLASTresult() eq ''){
			$cursor->setBLASTresult("keyword");
		}
	}
}

&addAnnotation();

# step 3. assess the blasted regions to find prophages (by DBSCAN)
&DBSCAN_main();
if ($debug_p_afterDBSCAN == 1){
	&printProphage(1);
	exit;
}

# step 3.5. join prophage regions if they seem to have considerable proteins from the same phage genome
&joinProphage();
if ($debug_p_afterJoin == 1){
	&printProphage(1);
	exit;
}
# step 4. identified integrases and (pre-identified)tRNAs are used to predict att sites
&searchAttachmentSite();

# finally, format output in Phage Finder's format
&printoutput();
exit;
