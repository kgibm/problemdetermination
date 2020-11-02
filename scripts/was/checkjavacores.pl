#!/usr/bin/perl

use strict;
use warnings;
use Time::Piece;

my $argc = $#ARGV + 1;
if ($argc == 0) {
  print "Usage: checkjavacores.pl [javacore.txt]+\n";
  exit;
}

foreach my $i (0 .. $#ARGV) {
  my $file = $ARGV[$i];
  my %threadFrames = ();
  my $toprint = "";
  my $pid = "";
  my $lastFrame = "";
  my $processThread = 0;
  my $printtime = "";
  my $cause = "";
  my $subcall = "";
  my $tracksubcall = 0;
  open(my $filehandle, $file) || die "Can't open $file: $!";
  while(my $line = <$filehandle>) {
    if ($line =~ /1TIDATETIME[^\d]+(\S+) at ([\d:]+)/) {
      $printtime = "${1} ${2}";
    } elsif ($line =~ /1TIFILENAME.*javacore\.[\d]+\.[\d]+\.([\d]+)\.[\d]+\.txt.*/) {
      $pid = ${1};
    } elsif ($line =~ /1TISIGINFO\s+Dump Event "([^"]+)" \([^\)]+\) received(.*)/) {
      $cause = $1;
    } elsif ($line =~ /3XMTHREADINFO      "([^"]+)"/) {
      $processThread = 1;
      $subcall = "";
    } elsif ($processThread && $line =~ /4XESTACKTRACE                at ([^\(]+)/) {
      my $thread = $1;
      if ($thread =~ /javax\/servlet\/http\/HttpServlet\.service/) {
        $threadFrames{$lastFrame . $subcall}++;
        $processThread = 0;
      } elsif ($thread =~ /org\/apache\/http\/impl\/client\/AbstractHttpClient\.execute/) {
        $tracksubcall = 1;
      } elsif ($tracksubcall) {
        $tracksubcall = 0;
        $subcall = " > " . $thread;
      }
      $lastFrame = $thread;
    }
  }
  close($filehandle);
  print "Time,PID,Cause";
  foreach my $key (keys %threadFrames) {
    print ",$key";
  }
  print ",Total\n";

  print "$printtime,$pid,$cause";
  my $total = 0;
  foreach my $key (keys %threadFrames) {
    print "," . $threadFrames{$key};
    $total += $threadFrames{$key};
  }
  print ",$total\n";
}
