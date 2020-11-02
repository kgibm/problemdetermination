#!/usr/bin/env perl
use Time::Piece;
foreach my $fileName (@ARGV) {
  $interval = 1;
  $hasTime = 0;
  $first = 0;
  open(my $fh, '<:encoding(UTF-8)', $fileName) or die "Could not open file '$fileName' $!";
  while (my $line = <$fh>) {
    chomp($line);
    $originalLine = $line;
    if ($line =~ /VMSTAT_INTERVAL = (\d+)$/) {
      $interval=$1;
      print "1 $line\n";
    } elsif ($line =~ /^\w+ \w+ \d+ \d+:\d+:\d+ \w+ \d+$/) {
      $line =~ s/^(.*) (\S+)( \d+)$/\1\3/;
      $tz = $2;
      $time = Time::Piece->strptime($line, "%a %b %e %H:%M:%S %Y");
      $first = 0;
      $hasTime = true;
      print "$originalLine\n";
    } elsif ($hasTime && $line =~ /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s*/) {
      # Ignore first one because `man vmstat`: "The first report produced gives averages since the last reboot."
      if ($first) {
        $time = $time + $interval;
        print "$originalLine " . $time->strftime("%Y-%m-%d %H:%M:%S") . "\n";
      } else {
        $first = true;
      }
    } else {
      print "$originalLine\n";
    }
  }
  close($fh);
}
