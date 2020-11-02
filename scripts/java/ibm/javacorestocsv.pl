#!/usr/bin/perl

use strict;
use warnings;
use Time::Piece;

my $argc = $#ARGV + 1;
if ($argc == 0) {
  print "Usage: javacores.pl [javacore.txt]+\n";
  exit;
}

my %pidlines = ();

my @printClassloaders = ();
my @printClassLoadersShort = ();
foreach my $i (0 .. $#printClassloaders) {
  my $printCl = $printClassloaders[$i];
  $printCl =~ /.*\/([^\/]+)$/;
  push(@printClassLoadersShort, $1);
}

my @countThreadNames = ("WebContainer");
my @countThreadFrames = ("com/ibm/ws/webcontainer/servlet/ServletWrapperImpl.handleRequest");

print "Time,PID,JRE_VSZ,Classes_VSZ,Threads_VSZ,#JMonitors,#NMonitors,#Threads";
foreach (@printClassLoadersShort) {
  my $cl = $_;
  print ",#$cl,#${cl}_Classes";
}
foreach (@countThreadNames) {
  my $t = $_;
  print ",#$t";
}
foreach (@countThreadFrames) {
  my $t = $_;
  print ",#$t";
}
print "\n";
foreach my $i (0 .. $#ARGV) {
  my $file = $ARGV[$i];
  my %classloaders = ();
  my %threads = ();
  my %threadFrames = ();
  my $toprint = "";
  my $nmonitors = 0;
  my $pid = "";
  my $lastcl = "";
  my $nthreads = 0;
  open(my $filehandle, $file) || die "Can't open $file: $!";
  while(my $line = <$filehandle>) {
    if ($line =~ /1TIDATETIME[^\d]+(\S+) at ([\d:]+)/) {
      $toprint .= "${1} ${2}";
    } elsif ($line =~ /1TIFILENAME.*javacore\.[\d]+\.[\d]+\.([\d]+)\.[\d]+\.txt.*/) {
      $pid = ${1};
      $toprint .= ",${pid}";
    } elsif ($line =~ /1MEMUSER\s+JRE[^\d]+([\d\,]+)/) {
      my $bytes = $1;
      $bytes =~ s/,//g;
      $toprint .= ",${bytes}";
    } elsif ($line =~ /3MEMUSER.*Classes[^\d]+([\d\,]+)/) {
      my $bytes = $1;
      $bytes =~ s/,//g;
      $toprint .= ",${bytes}";
    } elsif ($line =~ /3MEMUSER.*Threads[^\d]+([\d\,]+)/) {
      my $bytes = $1;
      $bytes =~ s/,//g;
      $toprint .= ",${bytes}";
    } elsif ($line =~ /2LKPOOLTOTAL[^\d]+([\d]+)/) {
      $toprint .= ",${1}";
    } elsif ($line =~ /2LKREGMON /) {
      $nmonitors++;
    } elsif ($line =~ /2XMPOOLLIVE\s+Current total number of live threads: ([\d]+)/) {
      $nthreads = $1;
    } elsif ($line =~ /2CLTEXTCLLOADER.*Loader ([^\(]+)/) {
      $lastcl = $1;
      if (!exists($classloaders{$lastcl})) {
        $classloaders{$lastcl} = {
          count => 0,
          classCount => 0
        };
      }
      $classloaders{$lastcl}{"count"} = $classloaders{$lastcl}{"count"} + 1;
    } elsif ($line =~ /3CLNMBRLOADEDCL[^\d]+([\d]+)/) {
      $classloaders{$lastcl}{"classCount"} = $classloaders{$lastcl}{"classCount"} + $1;
    } elsif ($line =~ /3XMTHREADINFO      "([^"]+)"/) {
      my $thread = $1;
      foreach (@countThreadNames) {
        my $t = $_;
        if (index($thread, $t) != -1) {
          if (!exists($threads{$t})) {
            $threads{$t} = 0;
          }
          $threads{$t} = $threads{$t} + 1;
        }
      }
    } elsif ($line =~ /4XESTACKTRACE                at ([^\(]+)/) {
      my $thread = $1;
      foreach (@countThreadFrames) {
        my $t = $_;
        if (index($thread, $t) != -1) {
          if (!exists($threadFrames{$t})) {
            $threadFrames{$t} = 0;
          }
          $threadFrames{$t} = $threadFrames{$t} + 1;
        }
      }
    }
  }
  $toprint .= ",${nmonitors},${nthreads}";
  foreach (@printClassloaders) {
    my $printCl = $_;
    if (exists($classloaders{$printCl})) {
      $toprint .= "," . $classloaders{$printCl}{"count"} . "," . $classloaders{$printCl}{"classCount"};
    } else {
      $toprint .= ",0,0";
    }
  }
  foreach (@countThreadNames) {
    my $t = $_;
    if (exists($threads{$t})) {
      $toprint .= "," . $threads{$t};
    } else {
      $toprint .= ",0";
    }
  }
  foreach (@countThreadFrames) {
    my $t = $_;
    if (exists($threadFrames{$t})) {
      $toprint .= "," . $threadFrames{$t};
    } else {
      $toprint .= ",0";
    }
  }
  $toprint .= "\n";
  if (!exists($pidlines{$pid})) {
    $pidlines{$pid} = ();
  }
  push(@{$pidlines{$pid}}, $toprint);
  close($filehandle);
}

sub extractDate {
  my ($str) = @_;
  $str =~ /([^,]+),/;
  my $dstr = $1;
  my $t = Time::Piece->strptime($dstr, "%Y/%m/%d %H:%M:%S");
  return $t->epoch;
}

foreach my $val (values %pidlines) {
  my @items = @$val;
  my @sortedItems = sort { extractDate($a) cmp extractDate($b) } @items;;
  foreach (@sortedItems) {
    print $_;
  }
}
