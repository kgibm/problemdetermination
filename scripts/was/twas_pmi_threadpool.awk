#!/usr/bin/awk -f
# usage: twas_pmi_threadpool.awk [-v "option=value"] tpv*xml... | sort -n
# Example: find . -name "tpv*xml" | TZ=IST-05:30 xargs ./twas_pmi_threadpool.awk -v "stat=(\"WebContainer\")" | sort -n
#
# Output (CSV):
# 010SortableDateTime,Date,Day,Time,Node,Server,JVM,ActiveCountAvg,PoolSizeAvg,DeclaredThreadHungCountAvg,File
#
# Options:
#   Statistic patern:
#     -v "stat=(\"WebContainer\")"
#   Suppress printing the CSV header:
#     -v noheader=true
#   Debug:
#     -v debug=true

BEGIN {
  if (!noheader) {
    printf("010SortableDateTime,Date,Day,Time,Node,Server,JVM,ActiveCountAvg,PoolSizeAvg,DeclaredThreadHungCountAvg,File\n");
  }
  "uname" | getline os;
  if (os == "Darwin") {
    bsd=1;
  }
}

/<Server name=/ {
  gsub(/.*name="/, "");
  gsub(/".*/, "");
  server = $0;
}

/<Node name/ {
  gsub(/.*name="/, "");
  gsub(/".*/, "");
  node = $0;
}

/<Snapshot/ {
  gsub(/.*time="/, "");
  gsub(/...".*/, "");

  if (bsd) {
    cmd = "date -r " $0 " +\"%Y%m%d%H%M%S\"";
  } else {
    cmd = "date -d @" $0 " +\"%Y%m%d%H%M%S\"";
  }
  cmd | getline sortabletime;
  close(cmd);

  if (bsd) {
    cmd = "date -r " $0 " +\"%Y-%m-%d\"";
  } else {
    cmd = "date -d @"$0" +\"%Y-%m-%d\"";
  }
  cmd | getline day;
  close(cmd);

  if (bsd) {
    cmd = "date -r " $0 " +\"%H:%M:%S\"";
  } else {
    cmd = "date -d @"$0" +\"%H:%M:%S\"";
  }
  cmd | getline time;
  close(cmd);

  days[sortabletime] = day;
  times[sortabletime] = time;

  finishPreviousSnapshot();

  if (debug) {
    printDebug("Snapshot " sortabletime);
  }
}

function finishPreviousSnapshot() {
  # No TS types to process
  twoSnapshotsAgo = lastSnapshot;
  lastSnapshot = sortabletime;
}

/<Stats.*statType="threadPoolModule"/ && !/<Stats.*name="threadPoolModule"/ {
  if (stat) {
    if ($0 ~ stat) {
      instat = 1;
    }
  } else {
    instat = 1;
  }
  if (instat && debug) {
    printDebug($0);
  }
}

# Details:
# https://www.ibm.com/support/knowledgecenter/en/SSAW57_9.0.5/com.ibm.websphere.nd.multiplatform.doc/ae/rprf_datacounter9.html
# https://www.ibm.com/support/knowledgecenter/en/SSAW57_9.0.5/com.ibm.websphere.javadoc.doc/web/apidocs/constant-values.html#com.ibm.websphere.pmi.stat.WSThreadPoolStats.ActiveCount
#
# ActiveCount 	3
# ActiveTime 	9
# ClearedThreadHangCount 	7
# ConcurrentHungThreadCount 	8
# CreateCount 	1
# DeclaredThreadHungCount 	6
# DestroyCount 	2
# PercentMaxed 	5
# PoolSize 	4
#
# Example stat:
# <Stats name="WebContainer" statType="threadPoolModule" il="-2" type="COLLECTION">
# <BRS id="3" lWM="0" hWM="738" cur="112" int="7.649461056E9" sT="1598734920001" lST="1598944076672" lB="0" uB="0">
# </BRS>
# <BRS id="4" lWM="1" hWM="770" cur="614" int="6.3860212735E10" sT="1598734920001" lST="1598944076671" lB="100" uB="900">
# </BRS>
# <CS id="6" sT="1598734955277" lST="1598734955277" ct="0">
# </CS>
# <CS id="7" sT="1598734955277" lST="1598734955277" ct="0">
# </CS>
# <RS id="8" sT="1598734955277" lST="1598944076671" lWM="0" hWM="0" cur="0" int="0.0"></RS>
# </Stats>
#
# Statistic types: https://www.ibm.com/support/knowledgecenter/SSAW57_9.0.5/com.ibm.websphere.javadoc.doc/web/apidocs/com/ibm/websphere/pmi/stat/WSStatistic.html?view=embed
# See toXML methods here:
# CS: CountStatistic: https://github.com/OpenLiberty/open-liberty/blob/master/dev/com.ibm.ws.monitor/src/com/ibm/ws/pmi/stat/CountStatisticImpl.java
# RS: RangeStatistic: https://github.com/OpenLiberty/open-liberty/blob/master/dev/com.ibm.ws.monitor/src/com/ibm/ws/pmi/stat/RangeStatisticImpl.java
# BRS: BoundedRangeStatistic: https://github.com/OpenLiberty/open-liberty/blob/master/dev/com.ibm.ws.monitor/src/com/ibm/ws/pmi/stat/BoundedRangeStatisticImpl.java
# TS: TimeStatistic: https://github.com/OpenLiberty/open-liberty/blob/master/dev/com.ibm.ws.monitor/src/com/ibm/ws/pmi/stat/TimeStatisticImpl.java

function getValue(line, attribute) {
  str = line;
  re = ".*" attribute "=\"";
  gsub(re, "", str);
  gsub(/".*/, "", str);
  val = str + 0;
  return val;
}

instat && /id="3"/ {
  activecounttotal[sortabletime] = activecounttotal[sortabletime] + getValue($0, "cur");
}

instat && /id="4"/ {
  poolsizetotal[sortabletime] = poolsizetotal[sortabletime] + getValue($0, "cur");
}

instat && /id="6"/ {
  declaredhungtotal[sortabletime] = declaredhungtotal[sortabletime] + getValue($0, "ct");
}

/<\/Stats/ {
  instat = 0;
}

FNR == 1 {
  if (!firstFNR) {
    firstFNR = 1;
  } else {
    endOfFile(0);
  }
  previousFilename = FILENAME;
}

function printDebug(message) {
  printf("DEBUG: %s\n", message);
}

END {
  endOfFile(1);
}

function endOfFile(lastFile) {
  finishPreviousSnapshot();

  for ( sortabletime in activecounttotal ) {
    printf( \
      "%s,%s %s,%s,%s,%s,%s,%s,%d,%d,%d,%s\n", \
      sortabletime, \
      days[sortabletime], \
      times[sortabletime], \
      days[sortabletime], \
      times[sortabletime], \
      node, \
      server, \
      node "_" server, \
      activecounttotal[sortabletime] + 0, \
      poolsizetotal[sortabletime] + 0, \
      declaredhungtotal[sortabletime] + 0, \
      previousFilename \
    );
  }

  cleanForNextFile();
}

function cleanForNextFile() {
  twoSnapshotsAgo=0;
  lastSnapshot=0;
  delete activecounttotal;
  delete poolsizetotal;
  delete declaredhungtotal;
  delete days;
  delete times;
  node="";
  server="";
}
