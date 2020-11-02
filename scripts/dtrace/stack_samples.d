#!/usr/sbin/dtrace -qs
/**
 * Usage: As root, run in a directory with sufficient disk space.
 * $ nohup /usr/sbin/dtrace -q -x ustackframes=10 -x stackframes=10 -s stack_samples.d > dtrace.out 2>&1 &
 * ... Run as long as needed ... To stop:
 * $ kill -INT `pgrep dtrace`
 */

# pragma D option bufsize=16m
# pragma D option dynvarsize=16m

dtrace:::BEGIN {
  printf("DTrace script started at %Y (%d)\n", walltimestamp, walltimestamp);
}

/**
 * A profile runs at some frequency on every CPU core thread.
 *
 * 99 Hz is 1/99 ~= 10ms. "The odd numbered rates, 99 and 199, are used
 * to avoid sampling in lockstep with other [periodic] activity and
 * producing misleading results." [1]
 *
 * [1] http://www.brendangregg.com/FlameGraphs/cpuflamegraphs.html
 */
profile:::profile-99 {
  /**
   * We place every kernel and user stack into an aggregate and dump
   * it out in a tick.
   */
  @stacks[walltimestamp, execname, pid, tid, stack(), ustack()] = count();
}

/**
 * A tick runs at some frequency on a single CPU core thread.
 */
tick-1s {
  printf("Tick covering 1s before %Y (%d)\n", walltimestamp, walltimestamp);
  printa(@stacks);
  trunc(@stacks);
}

dtrace:::END {
  printf("DTrace script ended at %Y\n", walltimestamp);
}
