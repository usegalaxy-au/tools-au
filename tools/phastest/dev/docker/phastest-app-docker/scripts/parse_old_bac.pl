my $tmp_dir = "/home/prion/phaster-app/DB/BAC_BACKUP/";

chdir $tmp_dir;

my $keep_headers={};

open(IN, "bacteria_all_select_header_lines_keep.db") or die "Cannot open list";
while(<IN>) {
	chomp ($_);
	 $keep_headers{ $_ } = $_;
	# push @keep_headers, $_;
}

my $output="bacteria_all_select_2011.db";

my $previous_line;

open(IN, "bacteria_all_select.db") or die "Cannot open list";
open(OUT, ">$output") or die "Cannot write $output";

my $count = 0;

while(<IN>) {
	chomp ($_);
	if ($_=~ m/>/){
		$previous_line = $_;
		print $previous_line;
		print "\n";
	}

	# if ($previous_line ~~ @keep_headers){
	if (exists $keep_headers{$previous_line}){
		print "EXISTS";
		print $previous_line;
		print "\n";

		print OUT $_.="\n";
		# print OUT "\n";
	}

}

close IN;
close OUT;