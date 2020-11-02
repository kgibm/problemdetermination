use strict;
use warnings;
no warnings 'portable';

print "Start,Length\n";
while (<>) {
  if ($_ =~ /^([a-f0-9]+)-([a-f0-9]+) .*/) {
    my $start = hex($1);
    my $end = hex($2);
    my $length = $end - $start;
    print "$1,$length\n";
  }
}
