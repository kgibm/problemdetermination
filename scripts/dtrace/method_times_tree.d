#!/usr/sbin/dtrace -Fqs
/**
 * Usage: As root, run in a directory with sufficient disk space.
 * $ nohup /usr/sbin/dtrace -Fqs method_times_tree.d -p ${PID} > dtrace.out 2>&1 &
 * ... reproduce ...
 * $ kill -INT `pgrep dtrace`
 */

# pragma D option bufsize=8m
# pragma D option dynvarsize=8m
# pragma D option bufsize=8m
# pragma D option specsize=8m
# pragma D option nspec=200

dtrace:::BEGIN {
  threshold = 100000000; /* 100ms */
  printf("DTrace script started at %Y, threshold=%d\n", walltimestamp, threshold);
}

pid$target:libjvm:JVM_StartThread:entry
{
  self->spec = speculation();
  self->start = walltimestamp;
  speculate(self->spec);
  printf("%s:%s:%s %d\n", probemod, probefunc, probename, self->start);
}

pid$target:libjvm:JVM_StartThread:return
/ self->spec && walltimestamp - self->start >= threshold /
{
  speculate(self->spec);
  self->now = walltimestamp;
  printf("%s:%s:%s %d; LWP %d, started %Y (%d), ended %Y (%d), duration = %d ns\n", probemod, probefunc, probename, self->now, tid, self->start, self->start, self->now, self->now, self->now - self->start);
  commit(self->spec);
}

pid$target:libjvm:JVM_StartThread:return
/ self->spec /
{
  discard(self->spec);
  self->spec = 0;
  self->start = 0;
  self->now = 0;
}

syscall::lwp_create:entry,
syscall::lwp_create:return,
fbt:unix:mutex_vector_enter:entry,
fbt:unix:mutex_vector_enter:return,
fbt:procfs:prbarrier:entry,
fbt:procfs:prbarrier:return
/ self->spec /
{
  speculate(self->spec);
  printf("%s:%s:%s %d\n", probemod, probefunc, probename, walltimestamp);
}

dtrace:::END {
  printf("DTrace script ended at %Y\n", walltimestamp);
}
