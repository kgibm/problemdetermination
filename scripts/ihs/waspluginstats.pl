#!/usr/bin/env perl
BEGIN {
  use Time::Piece;
  use List::Util qw(max sum);
  use POSIX;

  %timeseries = ();
  %servers = ();

  $min = undef;
  $max = undef;
  if (defined $ENV{'MINDATE'}) {
    $t = Time::Piece->strptime($ENV{'MINDATE'}, "%Y-%m-%d %H:%M:%S");
    $min = $t->epoch;
  }
  if (defined $ENV{'MAXDATE'}) {
    $t = Time::Piece->strptime($ENV{'MAXDATE'}, "%Y-%m-%d %H:%M:%S");
    $max = $t->epoch;
  }
  $type = $ENV{'STATS_TYPE'};
}
$line = $_;
chomp($line);

if ($line =~ /\[\S+ (\S+) (\d+) (\S+) (\d+)\] (\S+) (\S+) \- STATS: ws_server: serverSetFailoverStatus: Server (\S+) : pendingRequests (\d+) failedRequests (\d+) affinityRequests (\d+) totalRequests (\d+)\./) {
  $server = $7;
  $servers{$server} = 1;
  $pendingRequests = $8;
  $failedRequests = $9;
  $affinityRequests = $10;
  $totalRequests = $11;
  $time = Time::Piece->strptime("$4-$1-$2 $3", "%Y-%b-%d %H:%M:%S");
  $timeepoch = $time->epoch;
  if ((!defined($min) || (defined($min) && $timeepoch >= $min)) && (!defined($max) || (defined($max) && $timeepoch <= $max))) {
    $timeseries{$timeepoch}{$server}{"pendingRequests"} = $pendingRequests;
    $timeseries{$timeepoch}{$server}{"failedRequests"} = $failedRequests;
    $timeseries{$timeepoch}{$server}{"affinityRequests"} = $affinityRequests;
    $timeseries{$timeepoch}{$server}{"totalRequests"} = $totalRequests;
    $timeseries{$timeepoch}{$server}{"nonAffinityRequests"} = $totalRequests - $affinityRequests;
  }
}

END {
  $lasttime = undef;
  $size = keys %timeseries;
  if ($size < 3) {
    die "Insufficient data points found\n";
  } else {
    @serverNames = ();
    print "Time";
    foreach my $server (sort keys %servers) {
      push(@serverNames, $server);
      print ",$server";
    }
    print "\n";

    foreach my $key (sort keys %timeseries) {
      %val = %{$timeseries{$key}};
      $lasttime = gmtime($key);

      print $lasttime->strftime("%Y-%m-%d %H:%M:%S");
      foreach (@serverNames) {
        $server = $_;
        print "," . (defined($val{$server}{$type}) ? $val{$server}{$type} : 0);
      }
      print "\n";
    }
  }
}
