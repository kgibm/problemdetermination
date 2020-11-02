#!/usr/bin/env perl
BEGIN {
  use Time::Piece;
}
$line = $_;
chomp($line);
if ($line =~ /Reporting granularity: (\d+) second/) {
  $interval=$1;
} elsif ($line =~ /Time:  (\d\d\d\d)(\d\d)(\d\d) ([\d:]+):\d+ (\S+)/) {

  # Because Time can happen multiple times in a file, there's a chance we'll have two lines with the same time
  # This is more likely with an interval of 1s.

  $tz = $5;
  $time = Time::Piece->strptime("$1-$2-$3 $4", "%Y-%m-%d %H:%M:%S");
  $first = 0;
  if (!$hasTime) {
    $hasTime = 1;
    print "Time ($tz),CPU " . $interval . "s,Runqueue,Blocked,MemoryFree,PageIns,ContextSwitches,Wait,Steal\n";
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
