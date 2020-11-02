#!/usr/bin/env perl
use Time::Piece;
use Getopt::Long qw(:config gnu_getopt);

$printline = undef;

GetOptions(
  "printline" => \$printline
) or die("usage: hungthreads.pl SystemOut.log+\n");

foreach my $fileName (@ARGV) {
  open(my $fh, '<:encoding(UTF-8)', $fileName) or die "Could not open file '$fileName' $!";
  while (my $line = <$fh>) {
    chomp $line;
    if ($line =~ /\[(\d+)\/(\d+)\/(\d+) (\d+:\d+:\d+):\d+ ([^\]]+)\] \S+ ThreadMonitor W   WSVR0606W: Thread \"([^\"]+)\" \(([^\)]+)\) was previously reported to be hung but has completed.  It was active for approximately (\d+) milliseconds.  There is\/are (\d+) thread\(s\) in total in the server that still may be hung./) {
      $tz = $5;
      $threadname = $6;
      $threadid = $7;
      $end = Time::Piece->strptime("$3-$1-$2 $4", "%y-%m-%d %H:%M:%S");
      if (!$first) {
        $first = 1;
        print "Start ($tz),End ($tz),ResponseTime (ms),ThreadName,ThreadID,File";
        if ($printline) {
          print ",Line";
        }
        print "\n";
      }
      $start = $end - ($8 / 1000);
      print $start->strftime("%Y-%m-%d %H:%M:%S") . "," . $end->strftime("%Y-%m-%d %H:%M:%S") . ",$8,$threadname,$threadid,$fileName";
      if ($printline) {
        print "," . $line;
      }
      print "\n";
    }
  }
  close($fh);
}
