#!/usr/sbin/dtrace -qs

dtrace:::BEGIN {
  printf("DTrace script started at %Y\n", walltimestamp);
}

hotspot$target:::object-alloc
{
  printf("object-alloc %d\n", arg3);
}

dtrace:::END {
  printf("DTrace script ended at %Y\n", walltimestamp);
}
