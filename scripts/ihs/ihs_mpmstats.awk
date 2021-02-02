#!/usr/bin/awk -f
# usage: ihs_mpmstats.awk [-v "option=value"] error_log... | sort -n
#   (First chmod a+x ihs_mpmstats.awk)
#   The sort is needed because different files may be processed with the same times.
#   http://publib.boulder.ibm.com/httpserv/ihsdiag/2.0/mod_mpmstats.html
#
# Output (CSV):
# 010SortableDateTime,Day,Time,IdleThreads,ActiveThreads,ThreadsReadingFromClient,ThreadsWaitingOnBackendOrWritingToClient,ThreadsKeepAlive,ThreadsLogging,ThreadsDNS,ThreadsClosing,File,LineNumber

BEGIN {
  print "010SortableDateTime,Day,Time,IdleThreads,ActiveThreads,ThreadsReadingFromClient,ThreadsWaitingOnBackendOrWritingToClient,ThreadsKeepAlive,ThreadsLogging,ThreadsDNS,ThreadsClosing,File,LineNumber";
  warnings = 0;
}

/mpmstats: rdy/ {
  timeraw = $4;
  gsub(/:/, "", timeraw);
  isodate = sprintf("%d%02d%02d%s", $5, getMonthInteger($2), $3, timeraw);
  day = sprintf("%d-%02d-%02d", $5, getMonthInteger($2), $3);
  time = $4;

  printf("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",isodate,day,time,$9,$11,$13,$15,$17,$19,$21,$23,FILENAME,FNR);
}

/server reached MaxClients setting/ || /approaching MaxClients/ {
  printf("001WARNING (%s): %s\n", FILENAME, $0) > "/dev/stderr";
  warnings++;
}

function getMonthInteger(month) {
  if ( month == "Jan" ) {
    return 1;
  } else if (month == "Feb") {
    return 2;
  } else if (month == "Mar") {
    return 3;
  } else if (month == "Apr") {
    return 4;
  } else if (month == "May") {
    return 5;
  } else if (month == "Jun") {
    return 6;
  } else if (month == "Jul") {
    return 7;
  } else if (month == "Aug") {
    return 8;
  } else if (month == "Sep") {
    return 9;
  } else if (month == "Oct") {
    return 10;
  } else if (month == "Nov") {
    return 11;
  } else if (month == "Dev") {
    return 12;
  }
  return 0;
}

function printDebug(message) {
  printf("DEBUG: %s\n", message);
}

END {
  if (warnings > 0) {
    printf("001WARNING: %d warnings have been found (review stderr)\n", warnings) > "/dev/stderr";
    printf("99999999999999999999999WARNING: %d warnings have been found (review stderr)\n", warnings) > "/dev/stderr";
  }
}
