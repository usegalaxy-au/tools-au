# Author:   Scott Han
# Date:     July 20, 2022
#
# Calls Prodigal 2.6.3 directly on the front-end machine.
# Since prodigal is more effective over whole genome rather
# than parallelized fragments, this gives faster runtime.
#
# Usage:
#   call_prodigal.pl [Job number]
#
# Prodigal outputs .gff file.
# This code reads .gff and deposits output in .predict file.

my $num = $ARGV[0];

# Run the Prodigal job.
my $single_cmd = "prodigal -i $num\.fna -o $num.gff -f gff";
system("$single_cmd");

# Prepare output.
open(IN, "<", "$num.gff") || die("Cannot open $num.gff");
open(OUT, ">", "$num.predict") || die("Cannot write $num.predict");

my $counter = 0;

while ($_ = <IN>) {
    chomp($_);

    # Prints the header.
    if ($_ =~ /seqhdr=/) {
        $_ =~ /"(.+?)"/;
        print OUT ">$1\n";
    }

    # Prints the contents of the Prodigal output table.
    elsif ($_ =~ /\bconf=(.+?)\b/) {
        $counter++;
        my @arr = split("=", $&);

        # Only take hits with confidence higher than the threshold. Default 90.
        if ($arr[1] >= 50) {
            my $prodigal_hit = $1 if /\bCDS(.*)ID\b/;
            
            @arr = split(" ", $prodigal_hit);
            
            my $from = $arr[0];
            my $to = $arr[1];
            my $strand = $arr[3];
            my $orf_str = '';
            my $line = '';

            if ($counter >0 && $counter<10) {
                $orf_str='0000'.$counter;
            }elsif($counter >=10 && $counter<100) {
                $orf_str='000'.$counter;
            }elsif($counter >=100 && $counter<1000) {
                $orf_str='00'.$counter;
            }elsif($counter >=1000 && $counter<10000) {
                $orf_str='0'.$counter;
            }else{
                $orf_str=$counter;
            }

            if ($strand eq "-") {
                ($from, $to) = ($to, $from);    # If strand is negative, flip the start and end position.
            }

            $line = sprintf("%-10s %-10s %-10s %-5s %-20s\n", "orf$orf_str", $from, $to, $strand, "");
            print OUT $line;
        }
    }
}

close OUT;
close IN;
exit;
