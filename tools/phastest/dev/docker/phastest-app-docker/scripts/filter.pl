open(IN1, "<", "queries.txt");

my @arr = ();

while (<IN1>) {
    chomp $_;
    if ($_ =~ /^[A-Z]/) {
        push @arr, $_;
    }
}

close IN1;

open(IN2, "<", "test.txt");

while (my $query = <IN2>) {
    chomp $query;
    my $flag = 0;

    foreach my $elem (@arr) {
        chomp $elem;

        if ($elem =~ /$query/) {
            my $flag = 1;
            last;
        }
    }

    if ($flag) {
        print "$query\n";
    }
}

close IN2;