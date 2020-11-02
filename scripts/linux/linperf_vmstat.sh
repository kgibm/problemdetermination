#!/bin/sh
VMSTAT="vmstat.out"
SCREEN="screen.out"
command -v perl >/dev/null 2>&1 || { echo >&2 "perl required"; exit 1; }
command -v R >/dev/null 2>&1 || { echo >&2 "R required"; exit 1; }
[ ! -f "${VMSTAT}" ] && [ -f linperf_RESULTS.tar.gz ] && tar xzvf linperf_RESULTS.tar.gz
[ ! -f "${VMSTAT}" ] && echo "${VMSTAT} not found" && exit 1
[ ! -f "${SCREEN}" ] && echo "${SCREEN} not found" && exit 1
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export INPUT_TITLE=vmstat
export INPUT_COLS=2
grep VMSTAT_INTERVAL ${SCREEN} |\
  sed 's/^.*\(VMSTAT_INTERVAL = .*\)$/\1/g' |\
    cat - "${VMSTAT}" |\
      grep -v "^procs" |\
        grep -v "^ r" |\
          grep -v "^$" |\
            perl -n "${DIR}/linperf_vmstat.pl" \
              > "${INPUT_TITLE}.csv"
export TZ=`head -1 "${INPUT_TITLE}.csv" | sed 's/Time (\([^)]\+\)).*/\1/g'`
#R --silent --no-save -f "${DIR}/../r/graphcsv.r" < "${INPUT_TITLE}.csv"
#if hash eog 2>/dev/null; then
#  eog "$INPUT_TITLE.png" > /dev/null 2>&1 &
#fi
"${DIR}/../gnuplot/graphcsv.sh" "${INPUT_TITLE}.csv"

