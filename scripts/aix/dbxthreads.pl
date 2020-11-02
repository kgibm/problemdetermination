#!/usr/bin/perl

use strict;
use warnings;
use bigint qw/hex/;
use Math::BigFloat;

my $argc = $#ARGV + 1;
if ($argc == 0) {
  print "Usage: dbxthreads.pl [thread info.txt]+\n";
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
  my $threadscount = 0;
  my $threadscountunderbar = 0;
  while(my $line = <$filehandle>) {
    if ($line =~ /^\s+base\s+=\s+(0x\S+)\s+size\s+=\s+(0x\S+)\s*$/) {
      my $baseaddr = $1;
      my $size = $2;

      $baseaddr = processHex($baseaddr);
      $size = processHex($size);

      if ($size->bcmp($maxstack) < 0) {
        $total->badd($size);
        $threadscount++;

        if ($baseaddr->bcmp($bar) < 0) {
          $totalunderbar->badd($size);
          $threadscountunderbar++;
        }
      }
    }
  }
  print $threadscount . " Threads: " . getPrintable($total) . "\n";
  print $threadscountunderbar . " Threads under bar: " . getPrintable($totalunderbar) . "\n";
  close($filehandle);
}
