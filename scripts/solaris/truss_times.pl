#!/usr/bin/env perl

# nohup truss -d -E -f -i -l -o truss_`hostname`_`date +"%Y%m%d_%H%M"`.txt -p ${PID} &

use Time::Piece;
use Getopt::Long qw(:config gnu_getopt);
use List::Util qw(max sum);
use POSIX;

$threshold = undef;

GetOptions(
  "threshold=f" => \$threshold
) or die("usage: truss_times.pl [-threshold SECS] truss*.log+\n");

my %timeseries = ();
my $min = undef;
my $max = undef;
if (defined $ENV{'MINDATE'}) {
  my $t = Time::Piece->strptime($ENV{'MINDATE'}, "%Y-%m-%d %H:%M:%S");
  $min = $t->epoch;
}
if (defined $ENV{'MAXDATE'}) {
  my $t = Time::Piece->strptime($ENV{'MAXDATE'}, "%Y-%m-%d %H:%M:%S");
  $max = $t->epoch;
}
my $tz = undef;
my $basetime = undef;

foreach my $fileName (@ARGV) {
  open(my $fh, '<:encoding(UTF-8)', $fileName) or die "Could not open file '$fileName' $!";
  while (my $line = <$fh>) {
    chomp $line;
    if ($line =~ /Base time stamp:\s+(\S+)\s+\[\s*(\S+)\s+(\S+)\s+(\d+)\s+(\d+:\d+:\d+)\s+(\S+)\s+(\S+)\s*\]\s*/) {
      $tz = $6;
      $basetime = $1;
      my $time = localtime($basetime);
      print "Started at " . $time->strftime("%Y-%m-%d %H:%M:%S") . "\n";
    } elsif ($line =~ /^(\d+)\/(\d+):\s+(\d+\.\d+)\s+(\d\.\d+)\s+(.*)$/) {
      my $offset = $3;
      my $duration = $4;
      my $timeepoch = $basetime + $offset;
      if (!defined($threshold) || (defined($threshold) && $duration >= $threshold)) {
        if ((!defined($min) || (defined($min) && $timeepoch >= $min)) && (!defined($max) || (defined($max) && $timeepoch <= $max))) {
          if (!defined($timeseries{$timeepoch}{0})) {
            $timeseries{$timeepoch}{0} = $line;
          }
        }
      }
    } elsif ($line =~ /^(\d+)\/(\d+):\s+([\d.]+)\s+([\d.]+)\s+(.*)$/) {
      # TODO: Print Warning. Sometimes truss seems to have interleaved output (bug?)
    }
  }
  close($fh);
}

foreach my $key (sort keys %timeseries) {
  my %val = %{$timeseries{$key}};
  my $lasttime = localtime($key);
  print $lasttime->strftime("%Y-%m-%d %H:%M:%S") . " " . $val{0} . "\n";
}
