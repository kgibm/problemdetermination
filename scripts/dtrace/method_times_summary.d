#!/usr/sbin/dtrace -qs
/**
 * Usage: As root, run in a directory with sufficient disk space.
 * $ nohup /usr/sbin/dtrace -q -x ustackframes=10 -x stackframes=10 -p ${PID} -s method_times.d > dtrace.out 2>&1 &
 * ... reproduce ...
 * $ kill -INT `pgrep dtrace`
 */

# pragma D option bufsize=8m
# pragma D option dynvarsize=8m

dtrace:::BEGIN {
  printf("DTrace script started at %Y\n", walltimestamp);
}

syscall:::entry
/ pid == $target /
{
  self->start = timestamp;
}

syscall:::return
/ self->start /
{
  self->delta = timestamp - self->start;
  @averages[probefunc] = avg(self->delta);  
  @maximums[probefunc] = max(self->delta); 
  @counts[probefunc] = count();
  @sums[probefunc] = sum(self->delta);
  @times[probefunc] = quantize(self->delta);
  self->ts_sys = 0;
  self->delta = 0;
}

/**
 * A tick runs at some frequency on a single CPU core thread.
 */
tick-1s {
  printf("Tick covering 1s before %Y (%d)\n", walltimestamp, walltimestamp);
  printf("Average Durations (ns)\n");
  printa(@averages);
  printf("\nMaximum Durations (ns)\n");
  printa(@maximums);
  printf("\nCounts (ns)\n");
  printa(@counts);
  printf("\nSum Durations (ns)\n");
  printa(@sums);
  printf("\nQuantized Durations (ns)\n");
  printa(@times);
  trunc(@averages);
  trunc(@maximums);
  trunc(@counts);
  trunc(@sums);
  trunc(@times);
}

dtrace:::END {
  printf("DTrace script ended at %Y\n", walltimestamp);
}
