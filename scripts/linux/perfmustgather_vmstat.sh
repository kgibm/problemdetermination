#!/bin/sh
VMSTAT="vmstat.txt"
command -v perl >/dev/null 2>&1 || { echo >&2 "perl required"; exit 1; }
command -v R >/dev/null 2>&1 || { echo >&2 "R required"; exit 1; }
[ ! -f "${VMSTAT}" ] && [ -f mustGather_RESULTS*.tar.gz ] && tar xzvf mustGather_RESULTS*.tar.gz
[ ! -f "${VMSTAT}" ] && echo "${VMSTAT} not found" && exit 1
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -f "info.txt" ]; then
  export INPUT_TITLE="vmstat-`grep "^Platform: " info.txt | sed 's/Platform: Linux \([^ \.]\+\).*/\1/g'`"
else
  export INPUT_TITLE=vmstat
fi
export INPUT_COLS=2
cat "${VMSTAT}" |\
  perl -n "${DIR}/perfmustgather_vmstat.pl" \
    > "${INPUT_TITLE}.csv"
export TZ=`head -1 "${INPUT_TITLE}.csv" | sed 's/Time (\([^)]\+\)).*/\1/g'`
#R --silent --no-save -f "${DIR}/../r/graphcsv.r" < "${INPUT_TITLE}.csv"
#if hash readlink 2>/dev/null; then
#  readlink -f "$INPUT_TITLE.png" 2>/dev/null
#fi
#if hash eog 2>/dev/null; then
#  eog "$INPUT_TITLE.png" > /dev/null 2>&1 &
#fi
"${DIR}/../gnuplot/graphcsv.sh" "${INPUT_TITLE}.csv"

