#!/usr/bin/env perl
BEGIN {
  use Time::Piece;
}
$line = $_;
chomp($line);
if ($line =~ /VMSTAT_INTERVAL = (\d+)$/) {
  $interval=$1;
} elsif ($line =~ /^(\w+), (\w+) (\d+), (\d+) (\d+:\d+:\d+) (\w+) (\w+)$/) {
  $tz = $7;
  $time = Time::Piece->strptime("$1 $2 $3 $4 $5 $6", "%a %b %d %Y %r");
  $first = 0;
  if (!$hasTime) {
    $hasTime = 1;
    print "Time ($tz),CPU " . $interval . "s,Runqueue,Blocked,MemoryFree,ContextSwitches,Wait\n";
  }
} elsif ($line =~ /^(\w+)\s+(\w+)\s+(\d+)\s+(\d+:\d+:\d+)\s+(\w+)\s+(\d+)$/) {
  $tz = $7;
  $time = Time::Piece->strptime("$6-$2-$3 $4", "%Y-%b-%d %H:%M:%S");
  $first = 0;
  if (!$hasTime) {
    $hasTime = 1;
    print "Time ($tz),CPU " . $interval . "s,Runqueue,Blocked,MemoryFree,ContextSwitches,Wait\n";
  }
} elsif ($hasTime && $line =~ /^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s*$/) {
  # Ignore first one. See https://publib.boulder.ibm.com/httpserv/cookbook/Operating_Systems-Solaris.html#Operating_Systems-Solaris-Central_Processing_Unit_CPU-vmstat
  if ($first) {
    $time = $time + $interval;
    print $time->strftime("%Y-%m-%d %H:%M:%S") . "," . (100 - $22) . ",$1,$2,$5,$19,$3\n";
  } else {
    $first = true;
  }
}
