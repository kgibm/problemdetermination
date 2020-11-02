#!/usr/bin/env perl
BEGIN {
  use Time::Piece;
}
$line = $_;
chomp($line);
if ($line =~ /VMSTAT_INTERVAL = (\d+)$/) {
  $interval=$1;
} elsif ($line =~ /^\w+ \w+ \d+ \d+:\d+:\d+ \w+ \d+$/) {
  $line =~ s/^(.*) (\S+)( \d+)$/\1\3/;
  $tz = $2;
  $time = Time::Piece->strptime($line, "%a %b %e %H:%M:%S %Y");
  $first = 0;
  if (!$hasTime) {
    $hasTime = 1;
    print "Time ($tz),CPU,Runqueue,Blocked,MemoryFree,PageIns,ContextSwitches,Wait,Steal\n";
  }
} elsif ($hasTime && $line =~ /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
  # Ignore first one because `man vmstat`: "The first report produced gives averages since the last reboot."
  if ($first) {
    $time = $time + $interval;
    print $time->strftime("%Y-%m-%d %H:%M:%S") . "," . (100 - $15) . ",$1,$2," . ($4 + $5 + $6) . ",$7,$12,$16,$17\n";
  } else {
    $first = true;
  }
}
