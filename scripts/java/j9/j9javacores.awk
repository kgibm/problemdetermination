#!/usr/bin/awk -f
# usage: j9javacores.awk [-v "option=value"] javacore.txt... | sort -n
#
# Output (CSV):
# 0SortableDateTime,Date,Time,PID-JVMStartTime,Name,Cell,Node,Server,ThreadPool,ThreadName,Method,PackageTrimmed,MethodTrimmed,File,LineNumber
#
# Options:
#   Skip frame regex (in addition to built-in skips):
#     -v 'skipFrames=(java/net|com/ibm/db2)'
#   Override built-in skips. For example, to remove all built-in skips, just use a regex that doesn't match any java package/class/method name
#     -v 'builtInSkipFrames=!'
#   Only match certain threads regex:
#     -v 'onlyThreads=WebContainer'
#   Don't skip javacores that failed to take exclusive access (see https://github.com/eclipse/openj9/issues/9256):
#     -v 'nonexclusive=true'
#   Suppress printing the CSV header:
#     -v 'no_header=true'
#   Don't print warnings (quiet):
#     -v 'quiet=true'
#   Don't show file name and line number:
#     -v 'nosource=true'
#   The inverse of skipFrames; search for specific stack frames:
#     -v 'onlyFrames=(com/example)'
#   Customized mapping of MethodTrimmed:
#     -v 'trimmedMethods=BoundedBuffer$GetQueueLock.await:Idle,x.b:com/ibm/db2'
#   Look at native stacks instead of Java stacks:
#     -v 'nativeStacks=true'

BEGIN {
  rc=0;
  if (!no_header) {
    if (!nosource) {
      print "010SortableDateTime,Date,Time,PID-JVMStartTime,Name,Cell,Node,Server,ThreadPool,ThreadName,Method,PackageTrimmed,MethodTrimmed,File,LineNumber";
    } else {
      print "010SortableDateTime,Date,Time,PID-JVMStartTime,Name,Cell,Node,Server,ThreadPool,ThreadName,Method,PackageTrimmed,MethodTrimmed";
    }
  }

  if (!builtInSkipFrames) {
    builtInSkipFrames = "(java/lang/Object.wait|sun/misc/Unsafe.park|java/util/concurrent/DelayQueue.take|java/util/concurrent/LinkedBlockingQueue.take|java/util/concurrent/locks/LockSupport.park|java/util/concurrent/locks/LockSupport.parkNanos|java/util/concurrent/locks/AbstractQueuedSynchronizer\\$ConditionObject.await|\\(0x)";
  }

  if (trimmedMethods) {
    split(trimmedMethods, trimmedMethodsMapArray, ",");
    for (i in trimmedMethodsMapArray) {
      split(trimmedMethodsMapArray[i], itemArray, ":");
      trimmedMethodsMap[itemArray[1]]=itemArray[2];
    }
  }
}

# Windows newlines (\r\n) may throw things off and POSIX RS only supports
# a single character, so we just pass every $N to this function to clear
# any carriage return.
function processInput(str) {
  gsub(/\r$/, "", str);
  return str;
}

/^1TIDATETIME/ {
  # Reset state variables for each new javacore
  isGood=1;
  inStack=0;
  start="";
  name="";
  cell="";
  node="";
  jvm="";

  d=processInput($3);
  gsub(/\//, "-", d);
  t=processInput($5);
  sortable=sprintf("%s%s", d, t);
  gsub(/-/, "", sortable);
  gsub(/:/, "", sortable);
}

/^1CICMDLINE/ {
  if ($0 ~ /com.ibm.ws.runtime.WsServer/) {
    jvm = $NF;
    node = $(NF-1);
    cell = $(NF-2);
    name = cell "/" node "/" jvm;
  }
}

/^1CISTARTNANO/ {
  start=processInput($5);
}

/^1CIPROCESSID/ {
  if (!start || start == "") {
    start="unknown";
  }
  uniqueid=sprintf("%s-%s", processInput($4), start); # Since we don't necessarily have host name, use JVM start time to make the PID unique.
}

/^1TIPREPINFO/ {
  if ( processInput($0) ~ /Exclusive VM access not taken/ && !nonexclusive ) {
    if (!quiet) {
      printf("001WARNING (%s): Exclusive VM access not taken; skipping. To process, add the flag -v nonexclusive=true or to suppress this warning, add the flag -v quiet=true. See https://github.com/eclipse/openj9/issues/9256\n", FILENAME) > "/dev/stderr";
    }
    isGood=0;
    rc=1;
  }
}

isGood && /^3XMTHREADINFO / {
  if ( isThreadInteresting(processInput($0)) ) {
    threadName=getThreadName(processInput($0));
    threadPoolName=getThreadPoolName(processInput($0));
    inStack=1;
  } else {
    inStack=0;
  }
}

function getThreadName(line) {
  gsub(/3XMTHREADINFO +[^ ]/, "", line);
  gsub(/".*/, "", line);
  return line;
}

function getThreadPoolName(line) {
  line=getThreadName(line);
  gsub(/ : .*/, "", line);
  gsub(/-thread-.*/, "", line);
  return line;
}

function isThreadInteresting(line) {
  line=getThreadName(line);
  if ( onlyThreads ) {
    if ( line ~ onlyThreads ) {
      return isInterestingThreadID(line);
    } else {
      return 0;
    }
  }
  if ( \
      line ~ /WebContainer/ || \
      line ~ /Default Executor/ || \
      line ~ /LargeThreadPool/ || \
      line ~ /SIBJMSRAThreadPool/ || \
      line ~ /MessageListenerThreadPool/ || \
      line ~ /ORB\.thread\.pool/ || \
      line ~ /WebSphere WLM Dispatch Thread/ || \
      line ~ /WMQJCAResourceAdapter/ \
  ) {
    return isInterestingThreadID(line);
  }
  return 0;
}

function isInterestingThreadID(x) {
  if ( x ~ / : DMN/ ) {
    return 0;
  }
  return 1;
}

inStack && !nativeStacks && /^4XESTACKTRACE/ {
  if ( isStackFrameInteresting(processInput($0)) ) {
    stackFrame=getStackFrame(processInput($0));
    stackFramePackage=stackFrame;
    gsub(/[^\/]+\/[^\/]+/, "&@@", stackFramePackage);
    gsub(/@@.*/, "", stackFramePackage);
    stackFrameShort=stackFrame;
    gsub(/.*\//, "", stackFrameShort);
    if (trimmedMethodsMap[stackFrameShort]) {
      stackFrameShort=trimmedMethodsMap[stackFrameShort];
    }
    if (!nosource) {
      printf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",sortable,d,t,uniqueid,name,cell,node,jvm,cleanCommas(threadPoolName),cleanCommas(threadName),cleanCommas(stackFrame),cleanCommas(stackFramePackage),cleanCommas(stackFrameShort),FILENAME,FNR);
    } else {
      printf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",sortable,d,t,uniqueid,name,cell,node,jvm,cleanCommas(threadPoolName),cleanCommas(threadName),cleanCommas(stackFrame),cleanCommas(stackFramePackage),cleanCommas(stackFrameShort));
    }
    inStack=0;
  }
}

inStack && nativeStacks && /^4XENATIVESTACK/ {
  if ( isStackFrameInteresting(processInput($0)) ) {
    stackFrame=getStackFrame(processInput($0));
    stackFramePackage=stackFrame;
    stackFrameShort=stackFrame;
    if (trimmedMethodsMap[stackFrameShort]) {
      stackFrameShort=trimmedMethodsMap[stackFrameShort];
    }
    if (!nosource) {
      printf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",sortable,d,t,uniqueid,name,cell,node,jvm,cleanCommas(threadPoolName),cleanCommas(threadName),cleanCommas(stackFrame),cleanCommas(stackFramePackage),cleanCommas(stackFrameShort),FILENAME,FNR);
    } else {
      printf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",sortable,d,t,uniqueid,name,cell,node,jvm,cleanCommas(threadPoolName),cleanCommas(threadName),cleanCommas(stackFrame),cleanCommas(stackFramePackage),cleanCommas(stackFrameShort));
    }
    inStack=0;
  }
}

function getStackFrame(line) {
  if (line ~ /4XESTACKTRACE/) {
    gsub(/4XESTACKTRACE +at /, "", line);
    gsub(/\(.*/, "", line);
  } else {
    gsub(/4XENATIVESTACK +/, "", line);
    gsub(/ .*/, "", line);
    gsub(/\+.*/, "", line);
  }
  return line;
}

function isStackFrameInteresting(line) {
  stackFrame=getStackFrame(line);
  if ( onlyFrames ) {
    if ( stackFrame ~ onlyFrames ) {
      return 1;
    } else {
      return 0;
    }
  } else {
    if ( stackFrame ~ builtInSkipFrames ) {
      return 0;
    } else {
      if ( skipFrames && stackFrame ~ skipFrames ) {
        return 0;
      } else {
        return 1;
      }
    }
  }
}

function cleanCommas(str) {
  gsub(/,/, "_", str);
  return str;
}

END {
  exit rc;
}
