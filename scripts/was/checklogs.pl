#!/usr/bin/env perl
use Time::Piece;
use Getopt::Long qw(:config gnu_getopt);

$printline = undef;
$printfile = undef;

GetOptions(
  "printfile" => \$printfile,
  "printline" => \$printline
) or die("usage: checklogs.pl SystemOut.log+\n");

if (!defined($printfile) && @ARGV > 1) {
  $printfile = 1;
}

my $warnings = 0;
my $errors = 0;

foreach my $fileName (@ARGV) {
  open(my $fh, '<:encoding(UTF-8)', $fileName) or die "Could not open file '$fileName' $!";
  while (my $line = <$fh>) {
    chomp $line;
    if ($line =~ /\[(\d+)\/(\d+)\/(\d+) (\d+:\d+:\d+):(\d+) ([^\]]+)\]\s+(\S+)\s+(\S+)\s+(\S+)\s+(.*)$/) {
      $tz = $6;
      $threadid = $7;
      $component = $8;
      $type = $9;
      $message = $10;
      $timestr = "$3-$1-$2 $4";
      $analysis = "";

      $continue = 1;
      if ($message =~ /WSVR0605W/) {
        $analysis = "May be hung warning written";
      } elsif ($message =~ /WSVR0606W/) {
        $analysis = "May be hung warning completed";
      } elsif ($message =~ /TRAS0017I: .* (\S+)\.$/) {
        if ($1 eq "*=info") {
          $continue = 0;
        } else {
          $analysis = "Non-default trace: " . $1;
        }
      } elsif ($type eq "W") {
        $analysis = $line;
        $warnings++;
      } elsif ($type eq "E") {
        $analysis = $line;
        $errors++;
      } else {
        $continue = 0;
      }

      if ($continue) {
        $time = Time::Piece->strptime($timestr, "%y-%m-%d %H:%M:%S");
        if (!$first) {
          $first = 1;
          print "Time ($tz),Analysis";
          if ($printfile) {
            print ",File";
          }
          if ($printline) {
            print ",Line";
          }
          print "\n";
        }
        print $time->strftime("%Y-%m-%d %H:%M:%S") . ",$analysis";
        if ($printfile) {
          print "," . $fileName;
        }
        if ($printline) {
          print "," . $line;
        }
        print "\n";
      }
    }
  }
  close($fh);
}

print "Warnings=$warnings, Errors=$errors\n";
