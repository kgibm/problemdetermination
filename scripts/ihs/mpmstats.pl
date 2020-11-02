#!/usr/bin/env perl
BEGIN {
  use Time::Piece;
  print "Time,rdy,bsy,rd,wr,ka,log,dns,cls\n";
}
$line = $_;
chomp($line);
if ($line =~ /\[[^ ]+ ([^ ]+) ([0-9]+) ([^ ]+) ([0-9]+)\] \[notice\] mpmstats: rdy (\d+) bsy (\d+) rd (\d+) wr (\d+) ka (\d+) log (\d+) dns (\d+) cls (\d+)/) {
  $time = Time::Piece->strptime("$4-$1-$2 $3", "%Y-%b-%d %H:%M:%S");
  print $time->strftime("%Y-%m-%d %H:%M:%S") . ",$5,$6,$7,$8,$9,$10,$11,$12\n";
}
