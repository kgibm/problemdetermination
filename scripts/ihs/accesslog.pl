#!/usr/bin/env perl
BEGIN {
  use Time::Piece;
  eval "use Apache::LogRegex; 1" or die "You must install the Perl Apache::LogRegex module. For example: $ sudo cpan Apache::LogRegex";
  require Apache::LogRegex;
  use List::Util qw(max sum);
  use POSIX;

  %timeseries = ();

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
  $responsetime = 0;
  $data{"%t"} =~ /\[(\d+)\/([^\/]+)\/(\d+):([^ ]+) ([^\/]+)\]/;
  $tz = $5;
  $start = Time::Piece->strptime("$3-$2-$1 $4", "%Y-%b-%d %H:%M:%S");
  if (!$first) {
    $first = true;
    print "Time ($tz),Avg Resp ms,Max Resp ms,TPS,Arrivals per s,Errors per s,Avg Resp bytes,Max Resp bytes,Percent GETs\n";
  }

  $timeepoch = $start->epoch;

  if ((!defined($min) || (defined($min) && $timeepoch >= $min)) && (!defined($max) || (defined($max) && $timeepoch <= $max))) {
    $responsetime = -1;
    $responsebytes = -1;
    $code = 200;
    if (defined($data{"%D"}) && $data{"%D"} ne "-") {
      $responsetime = $data{"%D"} / 1000;
    } elsif (defined($data{"%T"}) && $data{"%T"} ne "-") {
      $responsetime = $data{"%T"} * 1000;
    }
    if (defined($data{"%b"}) && $data{"%b"} ne "-") {
      $responsebytes = $data{"%b"};
      if ($responsebytes eq "-") {
        $responsebytes = 0;
      }
    }
    if (defined($data{"%>s"}) && $data{"%>s"} ne "-") {
      $code = $data{"%>s"};
    }

    $end = $start + 0;
    if ($responsetime > 0) {
      $end += floor($responsetime / 1000);
    }

    $endepoch = $end->epoch;

    if ($responsetime > 0) {
      push(@{$timeseries{$endepoch}{0}}, $responsetime);
    } else {
      push(@{$timeseries{$endepoch}{0}}, 0);
    }
    if ($responsebytes > 0) {
      push(@{$timeseries{$endepoch}{1}}, $responsebytes);
    } else {
      push(@{$timeseries{$endepoch}{1}}, $responsebytes);
    }
    if ($code < 400) {
      $timeseries{$endepoch}{2}++;
    } else {
      $timeseries{$endepoch}{3}++;
    }
    $timeseries{$timeepoch}{4}++;
    if (defined($data{"%r"}) && $data{"%r"} ne "-" && $data{"%r"} =~ /^[^G]/) {
      $timeseries{$endepoch}{5}++;
    } else {
      $timeseries{$endepoch}{6}++;
    }
    $timeseries{$endepoch}{7}++;
  }
} else {
  die "Could not parse line " . $line . "\n";
}
END {
  $lasttime = undef;
  $size = keys %timeseries;
  if ($size == 0) {
    die "No data points found\n";
  } else {
    foreach my $key (sort keys %timeseries) {
      %val = %{$timeseries{$key}};
      $lasttime = gmtime($key);

      $responseTimesLength = @{$val{0}};
      $avgResponseTime = $responseTimesLength > 0 ? sum(@{$val{0}})/$responseTimesLength : 0;
      $maxResponseTime = $responseTimesLength > 0 ? max(@{$val{0}}) : 0;

      $responseBytesLength = @{$val{1}};
      $avgResponseByteLength = $responseBytesLength > 0 ? sum(@{$val{1}})/$responseBytesLength : 0;
      $maxResponseBytes = $responseBytesLength > 0 ? max(@{$val{1}}) : 0;

      $numnongets = defined($val{5}) ? $val{5} : 0;
      $numgets = defined($val{6}) ? $val{6} : 0;
      $total = defined($val{7}) ? $val{7} : 0;
      $percentgets = 0;
      if ($total > 0) {
	$percentgets = ceil(($numgets / $total) * 100);
      }

      $csv = $avgResponseTime . "," . $maxResponseTime . "," . (defined($val{2}) ? $val{2} : 0) . "," . (defined($val{4}) ? $val{4} : 0) . "," . (defined($val{3}) ? $val{3} : 0) . "," . $avgResponseByteLength . "," . $maxResponseBytes . "," . $percentgets;
      print $lasttime->strftime("%Y-%m-%d %H:%M:%S") . "," . $csv . "\n";
    }
    if ($size == 1) {
      $lasttime++;
      print $lasttime->strftime("%Y-%m-%d %H:%M:%S") . "," . $csv . "\n";
      $lasttime++;
      print $lasttime->strftime("%Y-%m-%d %H:%M:%S") . "," . $csv . "\n";
    } elsif ($size == 2) {
      $lasttime++;
      print $lasttime->strftime("%Y-%m-%d %H:%M:%S") . "," . $csv . "\n";
    }
  }
}
