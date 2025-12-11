open(FH, "<", "species.txt");

while (<FH>) {
    if ($_=~/^>\s(.*?)\s/) {
        if ($1 eq "???") {
            next;
        }
        else {
            print $1, "\n";
        }
    }
}

close FH;
