#!/usr/bin/env perl
BEGIN {
  use Time::Piece;
  eval "use Apache::LogRegex; 1" or die "You must install the Perl Apache::LogRegex module. For example: $ sudo cpan Apache::LogRegex";
  require Apache::LogRegex;
  use List::Util qw(max sum);
  use POSIX;

  %timeseries = ();
  %servers = ();
  $type = "totalRequests";

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
  $logformat = $ENV{'LOGFORMAT'};
  if (not defined $logformat) { die "LOGFORMAT envar not specified." };
  $lr = Apache::LogRegex->new($logformat);
  die "Unable to parse log line: $@" if ($@);
}
$line = $_;
chomp($line);
%data = $lr->parse($line);
if (%data) {
  $data{"%t"} =~ /\[(\d+)\/([^\/]+)\/(\d+):([^ ]+) ([^\/]+)\]/;
  $tz = $5;
  $start = Time::Piece->strptime("$3-$2-$1 $4", "%Y-%b-%d %H:%M:%S");
  $timeepoch = $start->epoch;

  if ((!defined($min) || (defined($min) && $timeepoch >= $min)) && (!defined($max) || (defined($max) && $timeepoch <= $max))) {
    $server = $data{"WAS=%{WAS}e"};
    $servers{$server} = 1;
    $timeseries{$timeepoch}{$server}{$type}++;
  }
} else {
  die "Could not parse line " . $line . "\n";
}

END {
  $lasttime = undef;
  $size = keys %timeseries;
  if ($size < 3) {
    die "Insufficient data points found\n";
  } else {
    @serverNames = ();
    print "Time ($tz)";
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
