#!/usr/bin/perl -w

### this program is used to extract all the DNA seqs of predicted regions of DNA 
### genomes of all the bacteria. It combines all them to make a DB
print `date`;
my $root = "/apps/phaster";
my $job_dir = "$root/phaster-app/JOBS";
chdir $job_dir;
my $des_dir = "$root/phaster-app/DB";
my $t1 = time();
my $DB_file = "$des_dir/z_DNA_fragment_DB";
open(OUT, ">$DB_file") or die "Cannot write $DB_file";
my $count = 0;
foreach my $id (split("\n", `ls |egrep -v "(ZZ_|z_|zz_|zzz)"`)){ 
	if (! -d $id){
		print STDOUT "Error: $id is NOT a directory \n";
		next;
	}
	# get id and go into dir of it to extract DB
	print "Extract $id\n";
	get_DNA($id, \*OUT);
	$count++;
	#last if ($count==2); # for debug
}
close OUT;
chdir $des_dir;
system("gzip $DB_file; rm $DB_file");
print "$des_dir/$DB_file\.gz is generated!!!\n";
print "Run time = ". (time()-$t1). " seconds\n";
print "Totally $count genomes are go-through\n";
exit;

sub get_DNA{
	my $id = shift;
	my $fd = shift;
	if (-s "$id/region_DNA.txt"){
		my @frags = split(">", `cat $id/region_DNA.txt`);
		my %hash_region_predicted_phage = get_regions("$id/summary.txt");
		if (! %hash_region_predicted_phage){
			print STDOUT "    No regions in summary.txt!!!\n";
                        return ;
                }
                for(my $i = 0;  $i <= $#frags; $i++){
			next if ($frags[$i]=~/^\s*$/);
			my ($num) = $frags[$i] =~/^(\d+)/;
			$frags[$i] =~ s/^(.*?)\n/$1  $id   $hash_region_predicted_phage{$num}\n/;
			print $fd  '>'. $frags[$i];
		}
	}else{
		print STDOUT "    No $id/region_DNA.txt\n";
	}
}

sub get_regions{
	my $file = shift;
	my %hash = ();
	open(F, $file);
	my $flag = 0;
	while(<F>){
		if ($_=~/--------------------/){
			$flag = 1;
			next;
		}
		if ($flag==1){
			my @tmp = split(/\s\s\s+/, $_);
			$tmp[$#tmp - 3] =~ s/(.*?),.*/$1/;
			print "        $tmp[1]  $tmp[$#tmp - 3]\n";
			$hash{$tmp[1]} = $tmp[$#tmp - 3];
		}
	}
	close F;
	return %hash;
}
