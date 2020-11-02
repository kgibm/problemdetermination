#!/bin/sh
VMSTAT="vmstat.out"
SCREEN="screen.out"
command -v perl >/dev/null 2>&1 || { echo >&2 "perl required"; exit 1; }
command -v R >/dev/null 2>&1 || { echo >&2 "R required"; exit 1; }
[ ! -f "${VMSTAT}" ] && [ -f solperf_RESULTS.tar.gz ] && tar xzvf solperf_RESULTS.tar.gz
[ ! -f "${VMSTAT}" ] && echo "${VMSTAT} not found" && exit 1
[ ! -f "${SCREEN}" ] && echo "${SCREEN} not found" && exit 1
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -f "uname.out" ]; then
  export INPUT_TITLE="vmstat-`sed 's/[^ ]\+ \([^ \.]\+\).*/\1/g' uname.out`"
else
  export INPUT_TITLE=vmstat
fi
export INPUT_COLS=2
grep VMSTAT_INTERVAL ${SCREEN} |\
  sed 's/^.*\(VMSTAT_INTERVAL = .*\)$/\1/g' |\
    cat - "${VMSTAT}" |\
      grep -v "^\s*kthr" |\
        grep -v "^\s*r\s+b" |\
          grep -v "^$" |\
            perl -n "${DIR}/solperf_vmstat.pl" \
              > "${INPUT_TITLE}.csv"
if [ -f "screen.out" ]; then
  export TZ=`head -1 screen.out | sed 's/.* \([^ ]\+\)/\1/g'`
fi
#R --silent --no-save -f "${DIR}/../r/graphcsv.r" < "${INPUT_TITLE}.csv"
#if hash readlink 2>/dev/null; then
#  readlink -f "$INPUT_TITLE.png" 2>/dev/null
#fi
#if hash eog 2>/dev/null; then
#  eog "$INPUT_TITLE.png" > /dev/null 2>&1 &
#fi
"${DIR}/../gnuplot/graphcsv.sh" "${INPUT_TITLE}.csv"

