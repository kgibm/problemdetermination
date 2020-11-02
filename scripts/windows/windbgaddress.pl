#!/usr/bin/perl

use strict;
use warnings;
use bigint qw/hex/;
use Math::BigFloat;

my $argc = $#ARGV + 1;
if ($argc == 0) {
  print "Usage: windbgaddress.pl [!address.txt]+\n";
  exit;
}

my $bar = 4294967296;
my $stackoverheaddiffmax = 2000000;
my @sizes = qw( bytes KB MB GB TB );
my $kb = Math::BigFloat->new("1024");
my $printDetailedFragmentation = 0;

sub processHex {
  my ($str) = @_;
  $str =~ s/`//g;
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
  my $totalHeaps = Math::BigInt->bzero();
  my $totalUnclassified = Math::BigInt->bzero();
  my $totalImages = Math::BigInt->bzero();
  my $totalFragmentation = Math::BigInt->bzero();
  my $max = Math::BigInt->bzero();
  my $min = $bar->copy();
  my $laststack = 0;
  my $lastend = Math::BigInt->bzero();
  my $threads = Math::BigInt->bzero();
  my $threadsoverhead = Math::BigInt->bzero();
  my $threadscount = 0;
  my $largestfree = Math::BigInt->bzero();
  my $largestfreeline = "";
  my %fragmentationHistogram = ();
  my $lastendall = Math::BigInt->bzero();
  while(my $line = <$filehandle>) {
    if ($line =~ /^[\*|\|]\-?\s+([\da-fA-F`]+)\s+([\da-fA-F`]+)\s+([\da-fA-F`]+)\s+(.*)$/) {
      my $baseaddr = $1;
      my $endaddrplusone = $2;
      my $regionsize = $3;
      my $usage = $4;

      $baseaddr = processHex($baseaddr);
      $endaddrplusone = processHex($endaddrplusone);
      $regionsize = processHex($regionsize);
      $usage =~ s/^\s+|\s+$//g;
      if ($baseaddr->bcmp($bar) < 0) {
        $total->badd($regionsize);
        if ($baseaddr->bcmp($max) > 0) {
          $max = $baseaddr->copy();
        }
        if ($baseaddr->bcmp($min) < 0) {
          $min = $baseaddr->copy();
        }
        my $diffall = $baseaddr->copy()->bsub($lastendall);
        if ($usage =~ /Stack /) {
          $threads->badd($regionsize);
          $threadscount++;

          # If the last address was a stack, then check if there's overhead
          if ($laststack == 1) {
            my $laststackdiff = $baseaddr->copy()->bsub($lastend);
            if ($laststackdiff->bcmp($stackoverheaddiffmax) < 0) {
              $threads->badd($laststackdiff);
              $total->badd($laststackdiff);
              $threadsoverhead->badd($laststackdiff);
            }
          }

          $laststack = 1;
          $lastend = $endaddrplusone->copy();
        } else {
          $laststack = 0;
          my $diff = $baseaddr->copy()->bsub($lastendall);
          $fragmentationHistogram{$diff}++;
          $totalFragmentation->badd($diff);
          if ($usage =~ /Heap \[Handle: ([^\]]+)\]/) {
            my $handle = $1;
            $totalHeaps->badd($regionsize);
          }
          if ($usage =~ /Free/) {
            if ($regionsize->bcmp($largestfree) > 0) {
              $largestfree = $regionsize->copy();
              $largestfreeline = $line;
              $totalFragmentation->badd($regionsize);
            }
          }
          if ($usage =~ /unclassified/) {
            $totalUnclassified->badd($regionsize);
          }
          if ($usage =~ /Image /) {
            $totalImages->badd($regionsize);
          }
        }
        if ($diffall->bcmp($largestfree) > 0) {
          $largestfree = $diffall->copy();
          $largestfreeline = $line;
        }
        $lastendall = $endaddrplusone->copy();
      }
    }
  }
  print "Bar = " . getPrintable($bar) . "\n";
  print "Min under bar: " . getPrintable($min) . "\n";
  print "Max under bar: " . getPrintable($max) . "\n";
  print $threadscount . " Threads under bar: " . getPrintable($threads) . " (overhead: " . getPrintable($threadsoverhead) . ")\n";
  print "Total Heaps' usage under bar: " . getPrintable($totalHeaps) . "\n";
  print "Total Images under bar: " . getPrintable($totalImages) . "\n";
  print "Total unclassified under bar: " . getPrintable($totalUnclassified) . "\n";
  print "Total fragmentation under bar: " . getPrintable($totalFragmentation) . "\n";
  print "Largest free region under bar: " . getPrintable($largestfree) . ": " . $largestfreeline . "\n";
  print "Total under bar: " . getPrintable($total) . "\n";
  if ($printDetailedFragmentation) {
    print "\n";
    print "Fragmentation under bar, sorted by count:\n";
    print "========================================\n";
    foreach my $key (sort { $fragmentationHistogram{$a} <=> $fragmentationHistogram{$b} } keys %fragmentationHistogram) {    
      printf "%s,%s,%s\n", $key, $fragmentationHistogram{$key}, getPrintable(Math::BigInt->new($fragmentationHistogram{$key} * $key), ",");
    }
    print "\n";
    print "Fragmentation under bar, sorted by size:\n";
    print "========================================\n";
    foreach my $key (sort {$a <=> $b} keys %fragmentationHistogram) {
      printf "%s,%s\n", $key, $fragmentationHistogram{$key};
    }
  }
  close($filehandle);
}
