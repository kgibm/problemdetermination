#!/usr/bin/perl

use strict;
use warnings;
use bigint qw/hex/;
use Math::BigFloat;

my $argc = $#ARGV + 1;
if ($argc == 0) {
  print "Usage: dbxcoremap.pl [coremap.txt]+\n";
  exit;
}

my $bar = 4294967296;
my @sizes = qw( bytes KB MB GB TB );
my $kb = Math::BigFloat->new("1024");
my $printDetailedFragmentation = 0;
my $maxstack = Math::BigInt->new("52428800");

sub processHex {
  my ($str) = @_;
  return hex($str);
}

sub getPrintable {
  my ($x, $delim) = @_;
  $delim ||= " / ";
  my $n = 0;
  my $size = Math::BigFloat->new($x->copy());
  while ($size->bcmp($kb) > 0) {
    $n++;
    $size->bdiv($kb);
  }
  return $x->as_hex() . $delim . $x->as_int() . $delim . sprintf("%.2f", $size) . " " . $sizes[$n];
}

foreach my $i (0 .. $#ARGV) {
  my $file = $ARGV[$i];
  open(my $filehandle, $file) || die "Can't open $file: $!";
  my $total = Math::BigInt->bzero();
  my $totalunderbar = Math::BigInt->bzero();
  my $sectionscount = 0;
  my $sectionscountunderbar = 0;
  while(my $line = <$filehandle>) {
    if ($line =~ /^\s+from\s+\(address\):\s+(0x\S+)\s+-\s+(0x\S+)\s*$/) {
      my $start = $1;
      my $end = $2;

      $start = processHex($start);
      $end = processHex($end);
      my $length = $end->copy()->bsub($start);

      $total->badd($length);
      $sectionscount++;

      if ($start->bcmp($bar) < 0) {
        $totalunderbar->badd($length);
        $sectionscountunderbar++;
        print "Under bar: Start " . getPrintable($start) . ", End " . getPrintable($end) . ", Length " . getPrintable($length) . "\n";
      }
    }
  }
  print $sectionscount . " Sections: " . getPrintable($total) . "\n";
  print $sectionscountunderbar . " Sections under bar: " . getPrintable($totalunderbar) . "\n";
  close($filehandle);
}
