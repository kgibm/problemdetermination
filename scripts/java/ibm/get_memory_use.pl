#!/usr/bin/perl

#DeveloperWorks Native Memory Article JavaCore Parsing Script
#(C) Copyright IBM Corp. 2008. All Rights Reserved.
#
#US Government Users Restricted Rights - Use, duplication or
#disclosure restricted by GSA ADP Schedule Contract with
#IBM Corp.

#A script to extract memory segment usage information from a JavaCore.
#
#Usage:
#perl get_memory_use.pl <javacore.txt>
#
#Where <javacore.txt> is the fully qualified path to a
#javacore.<date>.<time>.<pid>.txt file produced by the IBM Developer Kit >=
#Java 5.0
#
#Output is printed on stdout.
#       
#Andrew Hall
#andhall@uk.ibm.com
#
#Provided unsupported as part of the "Thanks for the Memory" Developerworks article

#Updated May 2014 by kevin.grigorenko@us.ibm.com to print more information.

use strict;
use warnings;

use Math::BigInt;

my $input_file = shift;

print "Input file not supplied\n" and usage() unless defined $input_file;

die "Input file $input_file does not exist" unless -e $input_file;

open(my $in,'<',$input_file) or die "Cannot open $input_file for reading: $!";

sub scaleIt {
    my( $size, $n ) = ( shift, 0 );
    ++$n and $size /= 1024 until $size < 1024;
    return sprintf "%.2f %s", $size, ( qw[ bytes KB MB GB TB ] )[ $n ];
}

#Parser state:

my $state = 'looking_for_meminfo';
my $current_segment_type;
my $current_data_point;
my %memory_usage_data_by_segment_type;
my $segmentsize = Math::BigInt->new('0x10000000');
my %memorysegmentmap;
my $typeclassram = Math::BigInt->new('0x10000');
my $typeclassrom = Math::BigInt->new('0x20000');
my $totalsegmentsprocessed = Math::BigInt->bzero();

sub processSegments {
    my ($seg, $start, $end, $reserved) = @_;
    my $quo = $start->copy()->bdiv($segmentsize)->numify();
    my ($endquo, $endremaining) = $end->copy()->bdiv($segmentsize);
    my $max = $endquo;
    if ($endremaining == 0) {
      $max--;
    }
    for (my $i = $quo; $i <= $max; $i++) {
      my $amount = 0;
      if ($quo == $max) {
        # If there's only one segment's worth
        $amount = $reserved->numify();
      } elsif ($i == $max) {
        # If it's the last segment, take the diff from the start of the segment
        $amount = $end->copy()->bsub($segmentsize->copy()->bmul($i))->numify();
      } elsif ($i == $quo) {
        # If this is the first segment, take into account the offset into the segment
        $amount = $segmentsize->copy()->bsub($start->copy()->bsub($segmentsize->copy()->bmul($i)))->numify();
        if ($amount == 0) {
          # If it starts at the segment boundary, then we know it takes the whole segment
          $amount = $segmentsize->numify();
        }
      } else {
        $amount = $segmentsize->numify();
      }
      $totalsegmentsprocessed->badd($amount);
      if (exists($memorysegmentmap{$i}{$seg})) {
        $memorysegmentmap{$i}{$seg} = $memorysegmentmap{$i}{$seg} + $amount;
      } else {
        $memorysegmentmap{$i}{$seg} = $amount;
      }
    }
}

#File read/parse loop

LINE: while(my $line = <$in>)
{
        if($state eq 'looking_for_meminfo')
        {
                if($line =~ /0SECTION\s+MEMINFO/)
                {
                        $state = 'reading_data';
                }
        }
        elsif($state eq 'reading_data')
        {
                if($line =~ /1STSEGTYPE\s+(.*)/ || $line =~ /1STHEAPTYPE\s+(.*)/)
                {
                        $current_segment_type = $1;
                        $current_segment_type =~ s/Object Memory/Java Heap/g;
                        $current_segment_type =~ s/\r//g;
                        $current_data_point = Math::BigInt->bzero();
                        $memory_usage_data_by_segment_type{$current_segment_type} = $current_data_point;
                        
                        print $line;
                }
                elsif($line =~ /1STSEGMENT/)
                {
                        my (undef,$segment_str,$start_str,$alloc_str,$end_str,$type_str,$bytes_str) = split /\s+/, $line;

                        $start_str =~ s/0x//g;
                        my $start_int = Math::BigInt->new('0x'.$start_str);

                        $alloc_str =~ s/0x//g;
                        my $alloc_int = Math::BigInt->new('0x'.$alloc_str);

                        $end_str =~ s/0x//g;
                        my $end_int = Math::BigInt->new('0x'.$end_str);

                        my $reserved = $end_int->copy()->bsub($start_int);

                        $current_data_point->badd($reserved);

                        my $breakdown = $current_segment_type;

                        if ($breakdown eq "Class Memory") {
                          $type_str =~ s/0x//g;
                          my $type_int = Math::BigInt->new('0x'.$type_str);
                          if (!($type_int->band($typeclassram)->is_zero())) {
                            $breakdown .= " (RAM)";
                          } else {
                            $breakdown .= " (ROM)";
                          }
                        }

                        processSegments($breakdown, $start_int->copy(), $end_int->copy(), $reserved->copy());
                }
                elsif($line =~ /1STHEAPREGION/)
                {
                        my (undef,$segment_str,$start_str,$end_str,$bytes_str) = split /\s+/, $line;

                        $start_str =~ s/0x//g;
                        my $start_int = Math::BigInt->new('0x'.$start_str);

                        $end_str =~ s/0x//g;
                        my $end_int = Math::BigInt->new('0x'.$end_str);

                        my $reserved = $end_int->copy()->bsub($start_int);

                        $current_data_point->badd($reserved);

                        processSegments($current_segment_type, $start_int->copy(), $end_int->copy(), $reserved->copy());
                }
                elsif($line =~ /0SECTION/)
                {
                        last LINE;
                }
                elsif($line =~ /1STHEAPTYPE/ || $line =~ /1STHEAPTOTAL/ || $line =~ /1STHEAPINUSE/ || $line =~ /1STHEAPFREE/ || $line =~ /1STSEGTOTAL/ || $line =~ /1STSEGINUSE/ || $line =~ /1STSEGFREE/)
                {
                        print $line;
                }
        }
        if($line =~ /[^0]MEMUSER/)
        {
                print $line;
        }
}

close($in);

#Print result

print "\nSegment Usage\tReserved Bytes\n==\n";

my $total = Math::BigInt->bzero();
foreach my $type (sort keys %memory_usage_data_by_segment_type)
{
        my $amt = $memory_usage_data_by_segment_type{$type};
        my $reserved_str = $amt->bstr();
        $total->badd($amt);
        print "$type\t$reserved_str (" . (scaleIt $amt->numify()) . ")\n";
}
print "==\nTotal\t" . $total->bstr() . " (" . (scaleIt $total->numify()) . ")\n\n";
if ($total->bcmp($totalsegmentsprocessed) != 0) {
  print "ERROR: Virtual address segment split total (" . $totalsegmentsprocessed->bstr() . ") doesn't match simple total.\n";
}

print "Virtual Address Segments (split " . $segmentsize->as_hex() . "/" . (scaleIt $segmentsize->numify()) . ")\n==\n";
foreach my $key (sort {$a<=>$b} keys %memorysegmentmap)
{
        my $keyHex = sprintf("%x", $key);
        print "0x$keyHex = ";
        my $first = 1;
        my $linetotal = Math::BigInt->bzero();
        foreach my $innerKey (sort keys %{ $memorysegmentmap{$key} })
        {
          if ($first == 1) {
            $first = 0;
          } else {
            print ", ";
          }
          my $x = $memorysegmentmap{$key}{$innerKey};
          $linetotal->badd($x);
          print "$innerKey (" . (scaleIt $x) . ")";
        }
        print ", Segment Total (" . $linetotal->as_int() . ")";
        print "\n";
}

sub usage
{
        print <<'END'; 

Usage:

        perl get_memory_use.pl <javacore.txt>
END

        exit 1;
}
