#!/usr/bin/perl -w

#this program will take http://www.ncbi.nlm.nih.gov/genomes/lproks.cgi online
# and compare the list file 'list'. If there is extra record
# from http://www.ncbi.nlm.nih.gov/genomes/lproks.cgi, then the extra part is 
# appended to 'list'.
my $t1 = time;
my $tmp_dir = "/var/www/html/phast/current/public/tmp";
my $exec_dir = "/var/www/html/phast/current/public/cgi-bin";

my $data = `cat $tmp_dir/list`;
#system("perl $exec_dir/z_html_parser3.pl > $tmp_dir/z_new_genome_list");
system("scp -i ~/.ssh/scp-key prion\@botha1.cs.ualberta.ca:phage/DB/z_current_NC_list $tmp_dir/z_current_NC_list");
my $new_data = `cat $tmp_dir/z_current_NC_list`;
my @array=();
my $total_count=0;
my $new_NC__count=0;
print "\n\n" . `date`;
foreach my $l (split("\n", $new_data)){
	$total_count++;
	if ($data !~/$l/s){
		$new_NC__count++;
		push @array, $l;
		print  $l."\n";
	}
}
foreach my $acc (@array){
	system("echo '-a  $acc' >> $tmp_dir/qq");
}

print STDERR "Total record count = $total_count\n";
print STDERR "New NC count = ". $new_NC__count ."\n";
my $t2=time;
print STDERR 'Total run time=' . ($t2-$t1)."\n";
if (`ps x` !~ /run_qq\.pl/s){
	system("perl $exec_dir/run_qq.pl ");
}
exit;

