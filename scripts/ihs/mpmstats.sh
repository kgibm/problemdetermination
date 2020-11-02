#!/bin/sh
command -v perl >/dev/null 2>&1 || { echo >&2 "perl required"; exit 1; }
command -v R >/dev/null 2>&1 || { echo >&2 "R required"; exit 1; }
if [ $# -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: mpmstats.sh error.log";
  if [ ! -f "$1" ]; then echo "$1 not found"; fi
  exit 1;
fi
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export INPUT_TITLE="mpmstats ${1}"
export INPUT_PNGFILE="${INPUT_TITLE//[^a-zA-Z0-9_]/}.png"
export INPUT_COLS=2
cat "$1" |\
  perl -n "${DIR}/mpmstats.pl" \
    > "$1.csv"
#R --silent --no-save -f "${DIR}/../r/graphcsv.r" < "$1.csv"
#if hash readlink 2>/dev/null; then
#  readlink -f "${INPUT_PNGFILE}" 2>/dev/null
#fi
#if hash eog 2>/dev/null; then
#  eog "${INPUT_PNGFILE}" > /dev/null 2>&1 &
#fi
"${DIR}/../gnuplot/graphcsv.sh" "$1.csv"

