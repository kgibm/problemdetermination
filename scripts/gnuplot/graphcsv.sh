#!/bin/sh
GNUPLOT_INPUT="$1"
GNUPLOT_NUMCOLUMNS=`awk -F, 'NR == 1 { print NF; exit }' "${GNUPLOT_INPUT}"`
GNUPLOT_NUMROWS=$(((${GNUPLOT_NUMCOLUMNS} - 1) / 2))
GNUPLOT_TMP=/tmp/gnuplots.gpi
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "set multiplot layout ${GNUPLOT_NUMROWS},2 scale 1.0,0.8" > ${GNUPLOT_TMP}
for ((GI=2;GI<=${GNUPLOT_NUMCOLUMNS};GI++)) do printf "plot '${GNUPLOT_INPUT}' using 1:%d\n" $GI; done >> ${GNUPLOT_TMP}
echo "unset multiplot; pause -1" >> ${GNUPLOT_TMP}
gnuplot "${DIR}/graphcsv.gpi" ${GNUPLOT_TMP}
