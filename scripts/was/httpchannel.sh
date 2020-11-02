#!/bin/sh
command -v perl >/dev/null 2>&1 || { echo >&2 "perl required"; exit 1; }
command -v R >/dev/null 2>&1 || { echo >&2 "R required"; exit 1; }
if [ $# -ne 2 ] || [ ! -f "$2" ]; then
  echo "usage: accesslog.sh NCSALogFormat access.log. Example NCSALogFormat: \"%h %i %u %t \\\\\\\"%r\\\\\\\" %s %b %D\"";
  if [ ! -f "$2" ]; then echo "$2 not found"; fi
  exit 1;
fi
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export LOGFORMAT="$1"
if [ -z "$LOGFORMAT" ]; then echo "usage: accesslog.sh NCSALogFormat access.log. Example NCSALogFormat: \"%h %i %u %t \\\\\\\"%r\\\\\\\" %s %b %D\""; exit 1; fi
echo "LogFormat: ${LOGFORMAT}"
export INPUT_TITLE="access log ${2}"
export INPUT_PNGFILE="${INPUT_TITLE//[^a-zA-Z0-9_]/}.png"
export INPUT_COLS=2
cat "$2" |\
  perl -n "${DIR}/../ihs/accesslog.pl" \
    > "$2.csv"
export TZ=`head -1 "$2.csv" | sed -n "s/^Time (\([^)]\+\)).*$/\1/p"`
#R --silent --no-save -f "${DIR}/../r/graphcsv.r" < "$2.csv" && \
#  if hash readlink 2>/dev/null; then
#    readlink -f "${INPUT_PNGFILE}" 2>/dev/null
#  fi &&
#    if hash eog 2>/dev/null; then
#      eog "${INPUT_PNGFILE}" > /dev/null 2>&1 &
#    fi
"${DIR}/../gnuplot/graphcsv.sh" "$2.csv"

