#!/usr/bin/awk -f
# usage: ncsa_response_times.awk [-v "option=value"] access_log... | sort -n
#   (First chmod a+x ncsa_response_times.awk)
#   The sort is needed because statistics are stored in an associative array dumped at the end and it's unordered.
#   Default LogFormat is assumed to be LogFormat "%h %l %u %t \"%r\" %>s %b %D \"%{WAS}e\" %X" common
#   Field descriptions: https://httpd.apache.org/docs/current/mod/mod_log_config.html#formats
#
# Output (CSV):
# 010SortableDateTime,Date,Day,Time,ArrivalsPer%s,ThroughputAllPer%s,Throughput4xxPer%s,Throughput5xxPer%s,ResponseTimesSumPer%s(%s),MeanResponseTimePer%s(%s),MaxResponseTimePer%s(%s),ResponseBytesSumPer%s,MeanResponseSizeBytesPer%s,MaxResponseSizeBytesPer%s
#
# Options:
#   Column offset of %D starting from the left (1 is the first column, 2 is second, etc.):
#     -v response_time_offset_left=X
#   Column offset of %D starting from the right (0 is the last column, 1 is second-to-last, etc.):
#     -v response_time_offset_right=X
#   Column offset of %t starting from the left (1 is the first column, 2 is second, etc.):
#     -v date_offset_left=X
#   Column offset of %t starting from the right (0 is the last column, 1 is second-to-last, etc.):
#     -v date_offset_right=X
#   Column offset of %s starting from the left (1 is the first column, 2 is second, etc.):
#     -v status_offset_left=X
#   Column offset of %s starting from the right (0 is the last column, 1 is second-to-last, etc.):
#     -v status_offset_right=X
#   Column offset of %b starting from the left (1 is the first column, 2 is second, etc.):
#     -v response_size_offset_left=X
#   Column offset of %b starting from the right (0 is the last column, 1 is second-to-last, etc.):
#     -v response_size_offset_right=X
#   Column offset of %{WAS}e starting from the left (1 is the first column, 2 is second, etc.):
#     -v jvm_offset_left=X
#   Column offset of %{WAS}e starting from the right (0 is the last column, 1 is second-to-last, etc.):
#     -v jvm_offset_right=X
#   Per-minute instead of per-second:
#     -v per_minute=true
#   Suppress printing the CSV header:
#     -v noheader=true
#   Response times in milliseconds instead of microseconds:
#     -v responsems=true
#   Debug:
#     -v debug=true
#   Divide transaction rates:
#     -v divtranrates=X
#   Don't skip rows with 0 responses:
#     -v noskip0=true
#   ODR %t time format:
#     -v odrtimeformat=true

BEGIN {
  per_second = 1;
  per_title = "S";
  if (per_minute) {
    per_second = 0;
    per_title = "M";
  }
  if (length(date_offset_left) == 0 && length(date_offset_right) == 0) {
    date_offset_left = 4;
  }
  if (length(status_offset_left) == 0 && length(status_offset_right) == 0) {
    status_offset_left = 9;
  }
  if (length(response_time_offset_left) == 0 && length(response_time_offset_right) == 0) {
    response_time_offset_right = 2;
  }
  if (length(response_size_offset_left) == 0 && length(response_size_offset_right) == 0) {
    response_size_offset_left = 10;
  }

  if (odrtimeformat) {
    responsems = 1;
  }

  responseunit = "us";
  if (responsems) {
    responseunit = "ms";
  }
  if (!divtranrates) {
    divtranrates = 1;
  }
  hasJVMs = 0;
}

function printHeader() {
  if (!noheader) {
    printf( \
      "010SortableDateTime,Date,Day,Time,ArrivalsPer%s,ThroughputAllPer%s,Throughput4xxPer%s,Throughput5xxPer%s,ResponseTimesSumPer%s(%s),MeanResponseTimePer%s(%s),MaxResponseTimePer%s(%s),ResponseBytesSumPer%s,MeanResponseSizeBytesPer%s,MaxResponseSizeBytesPer%s", \
      per_title, \
      per_title, \
      per_title, \
      per_title, \
      per_title, \
      responseunit, \
      per_title, \
      responseunit, \
      per_title, \
      responseunit, \
      per_title, \
      per_title, \
      per_title \
    );
    if (hasJVMs) {
      printf(",JVM");
    }
    printf("\n");
  }
}

# Match every line
{
  if (date_offset_left) {
    date = $(date_offset_left);
  } else {
    date = $(NF - date_offset_right);
  }
  if (status_offset_left) {
    status = $(status_offset_left);
  } else {
    status = $(NF - status_offset_right);
  }

  if (!odrtimeformat) {
    gsub(/\[/, "", date);
    gsub(/\//, ":", date);
    split(date, date_pieces, ":");
    isoihsdate = sprintf("%d%02d%02d%02d%02d%02d", date_pieces[3], getMonthInteger(date_pieces[2]), date_pieces[1], date_pieces[4], date_pieces[5], date_pieces[6]);
    day = sprintf("%d-%02d-%02d", date_pieces[3], getMonthInteger(date_pieces[2]), date_pieces[1]);
    time = sprintf("%02d:%02d:%02d", date_pieces[4], date_pieces[5], date_pieces[6]);
  } else {
    # 09/sept./2021:10:36:54
    split(date, pieces, "/");
    split(pieces[3], date_pieces, ":");
    isoihsdate = sprintf("%d%02d%02d%02d%02d%02d", date_pieces[1], getMonthIntegerODR(pieces[2]), pieces[1], date_pieces[2], date_pieces[3], date_pieces[4]);
    day = sprintf("%d-%02d-%02d", date_pieces[1], getMonthIntegerODR(pieces[2]), pieces[1]);
    time = sprintf("%02d:%02d:%02d", date_pieces[2], date_pieces[3], date_pieces[4]);
  }

  if (!per_second) {
    gsub(/..$/, "", isoihsdate);
    gsub(/:..$/, "", time);
  }

  if (response_time_offset_left) {
    response_time = $(response_time_offset_left);
  } else {
    response_time = $(NF - response_time_offset_right);
  }

  if (response_size_offset_left) {
    response_size = $(response_size_offset_left);
  } else {
    response_size = $(NF - response_size_offset_right);
  }

  arrivalisoihsdate = isoihsdate + 0;
  if (!per_second) {
    arrivalisoihsdate *= 100;
  }
  originalarrivalisoihsdate = arrivalisoihsdate;
  if (!odrtimeformat) {
    if (responsems) {
      response_time = (response_time + 0) / 1000;
      if (response_time >= 1000) {
        arrivalisoihsdate -= response_time / 1000;
        arrivalisoihsdate = int(arrivalisoihsdate);
      }
    } else {
      # microseconds
      if (response_time >= 1000000) {
        arrivalisoihsdate -= response_time / 1000000;
        arrivalisoihsdate = int(arrivalisoihsdate);
      }
    }
  } else {
    response_time = response_time + 0;
    arrivalisoihsdate -= response_time / 1000;
    arrivalisoihsdate = int(arrivalisoihsdate);
  }

  if (int(arrivalisoihsdate % 100) >= 60) {
    arrivalisoihsdate -= 40;
  }
  if (!per_second) {
    arrivalisoihsdate = int(arrivalisoihsdate / 100);
  }

  if (arrivalisoihsdate == 0) {
    printf("001WARNING (%s): Could not parse date for %s %s\n", FILENAME, $0, isoihsdate) > "/dev/stderr";
  }

  key = "all";

  if (jvm_offset_left) {
    key = $(jvm_offset_left);
    gsub(/"/, "", key);
    hasJVMs = 1;
  } else if (length(jvm_offset_right) > 0) {
    key = $(NF - jvm_offset_right);
    gsub(/"/, "", key);
    hasJVMs = 1;
  }

  arrival_count = arrival_counts[key, arrivalisoihsdate] + 0;
  arrival_counts[key, arrivalisoihsdate] = arrival_count + 1;

  arrival_counts[key, originalarrivalisoihsdate] = arrival_counts[key, originalarrivalisoihsdate] + 0;

  if (debug) {
    printDebug($0 "; date: " date ", status: " status ", isoihsdate: " isoihsdate ", day: " day ", time: " time ", responsetime: " response_time);
  }

  sum = response_time_sums[key, isoihsdate] + 0;
  response_time_sums[key, isoihsdate] = sum + response_time;
  
  sum = response_size_sums[key, isoihsdate] + 0;
  response_size_sums[key, isoihsdate] = sum + response_size;
  
  count = response_time_counts[key, isoihsdate] + 0;
  response_time_counts[key, isoihsdate] = count + 1;

  max = response_time_maximums[key, isoihsdate] + 0;
  if (response_time > max) {
    response_time_maximums[key, isoihsdate] = response_time;
  }

  max = response_size_maximums[key, isoihsdate] + 0;
  if (response_size > max) {
    response_size_maximums[key, isoihsdate] = response_size;
  }

  count = errors4xx_counts[key, isoihsdate] + 0;
  if (status >= 400 && status < 500) {
    count = count + 1;
  }
  errors4xx_counts[key, isoihsdate] = count;

  count = errors5xx_counts[key, isoihsdate] + 0;
  if (status >= 500) {
    count = count + 1;
  }
  errors5xx_counts[key, isoihsdate] = count;

  days[key, isoihsdate] = day;
  times[key, isoihsdate] = time;
}

function getMonthInteger(month) {
  if (month == "Jan") {
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
  } else if (month == "Dec") {
    return 12;
  }
  return 0;
}

function getMonthIntegerODR(month) {
  if (month ~ /jan/) {
    return 1;
  } else if (month ~ /feb/) {
    return 2;
  } else if (month ~ /mar/) {
    return 3;
  } else if (month ~ /apr/) {
    return 4;
  } else if (month ~ /may/) {
    return 5;
  } else if (month ~ /jun/) {
    return 6;
  } else if (month ~ /jul/) {
    return 7;
  } else if (month ~ /aug/) {
    return 8;
  } else if (month ~ /sep/) {
    return 9;
  } else if (month ~ /oct/) {
    return 10;
  } else if (month ~ /nov/) {
    return 11;
  } else if (month ~ /dec/) {
    return 12;
  }
  return 0;
}

function printDebug(message) {
  printf("DEBUG: %s\n", message);
}

function array2d_tokeys(array) {
  delete a2d2k;
  for (key in array) {
    split(key, pieces, SUBSEP);
    if (length(a2d2k[pieces[1]]) == 0) {
      a2d2k[pieces[1]] = pieces[2];
    } else {
      a2d2k[pieces[1]] = a2d2k[pieces[1]] SUBSEP pieces[2];
    }
  }
}

END {
  array2d_tokeys(arrival_counts);
  printHeader();
  for (key in a2d2k) {
    split(a2d2k[key], pieces, SUBSEP);
    for (piecesKey in pieces) {
      date = pieces[piecesKey];
      dt = days[key, date];
      tm = times[key, date];
      if (!dt) {
        if (per_second) {
          dt = sprintf("%d-%02d-%02d", date / 10000000000, (date / 100000000) % 1000, (date / 1000000) % 100);
          tm = sprintf("%d:%02d:%02d", (date / 10000) % 100, (date / 100) % 100, date % 100);
        } else {
          dt = sprintf("%d-%02d-%02d", date / 100000000, (date / 1000000) % 1000, (date / 10000) % 100);
          tm = sprintf("%d:%02d", (date / 100) % 100, date % 100);
        }
      }
      arrivals = (arrival_counts[key, date] + 0) / divtranrates;
      responses = (response_time_counts[key, date] + 0) / divtranrates;

      # ct is to compute averages. We don't divide by divtranrates here as that would skew the average
      ct = response_time_counts[key, date] + 0
      if (ct == 0) {
        ct = 1;
      }

      if (responses > 0 || (responses == 0 && noskip0)) {
        printf( \
          "%s,%s %s,%s,%s,%d,%d,%d,%d,%d,%.2f,%d,%d,%.2f,%d", \
          date, \
          dt, \
          tm, \
          dt, \
          tm, \
          arrivals, \
          responses, \
          errors4xx_counts[key, date] + 0, \
          errors5xx_counts[key, date] + 0, \
          response_time_sums[key, date] + 0, \
          (response_time_sums[key, date] + 0) / ct, \
          response_time_maximums[key, date] + 0, \
          response_size_sums[key, date], \
          (response_size_sums[key, date] + 0) / ct, \
          response_size_maximums[key, date] \
        );
        if (key != "all") {
          printf(",%s", key);
        }
        printf("\n");
      }
    }
  }
}
