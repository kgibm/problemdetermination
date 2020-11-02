#!/bin/sh

function usage() {
  echo "usage: portstats.sh PORT_1 PORT_2 ... PORT_N"
  echo "       Summarize network connection statistics. The default is to look at"
  echo "       local addresses only (i.e. connections *to* the ports)."
  echo ""
  echo "       OPENING represents SYN_SENT and SYN_RECV states."
  echo "       CLOSING represents FIN_WAIT1, FIN_WAIT2, TIME_WAIT, CLOSED, CLOSE_WAIT,"
  echo "                          LAST_ACK, CLOSING, and UNKNOWN states."
  echo ""
  echo "Options"
  echo "  -l, --local       Default. Only analyze the Local Address column."
  echo "  -f, --foreign     Only analyze the Foreign Address column."
  echo "  -b, --both        Analyze both Local and Foreign Address columns."
  echo "  -z, --nonzero     Only print a port result if it has some non-zero counts."
  echo "  -q, --quiet       Do not print NOTE sections."
  echo "  -n, --nototals    Do not print the Totals line."
  echo ""
  exit;
}

# Hints
# Linux: portstats.sh `seq 80 90`

NUM_PORTS=0
OS=`uname`
SEARCH=1
QUIET=0
NOTOTALS=0
NONZERO=0

for c in $*
do
  case $c in
  -l)
    SEARCH=1
    ;;
  --local)
    SEARCH=1
    ;;
  -f)
    SEARCH=2
    ;;
  --foreign)
    SEARCH=2
    ;;
  -b)
    SEARCH=3
    ;;
  --both)
    SEARCH=3
    ;;
  -q)
    QUIET=1
    ;;
  --quiet)
    QUIET=1
    ;;
  -n)
    NOTOTALS=1
    ;;
  --nototals)
    NOTOTALS=1
    ;;
  -z)
    NONZERO=1
    ;;
  --nonzero)
    NONZERO=1
    ;;
  -help)
    usage;
    ;;
  --help)
    usage;
    ;;
  -usage)
    usage;
    ;;
  --usage)
    usage;
    ;;
  -h)
    usage;
    ;;
  -?)
    usage;
    ;;
  *)
    PORTS[$NUM_PORTS]=$c
    NUM_PORTS=$((NUM_PORTS + 1));
    ;;
  esac
done

# Expects i and AWKSEARCH variables
function search() {
  ESTABLISHED[$i]=$((${ESTABLISHED[$i]} + `echo "$NETSTAT" | grep ESTABLISHED | awk "$AWKSEARCH" | grep "$PORT" | wc -l`));
  OPENING[$i]=$((${OPENING[$i]} + `echo "$NETSTAT" | grep SYN | awk "$AWKSEARCH" | grep "$PORT" | wc -l`));
  CLOSING[$i]=$((${CLOSING[$i]} + `echo "$NETSTAT" | grep WAIT | awk "$AWKSEARCH" | grep "$PORT" | wc -l`));
  CLOSING[$i]=$((${CLOSING[$i]} + `echo "$NETSTAT" | grep CLOS | awk "$AWKSEARCH" | grep "$PORT" | wc -l`));
  CLOSING[$i]=$((${CLOSING[$i]} + `echo "$NETSTAT" | grep LAST_ACK | awk "$AWKSEARCH" | grep "$PORT" | wc -l`));
  CLOSING[$i]=$((${CLOSING[$i]} + `echo "$NETSTAT" | grep UNKNOWN | awk "$AWKSEARCH" | grep "$PORT" | wc -l`));
}

if [ "$NUM_PORTS" -gt "0" ]; then
  if [ "$QUIET" -eq "0" ]; then
    if [ "$SEARCH" -eq "1" ]; then
      echo "NOTE: Only analyzing local addresses. See usage for more information."
    elif [ "$SEARCH" -eq "2" ]; then
      echo "NOTE: Only analyzing foreign addresses. See usage for more information."
    elif [ "$SEARCH" -eq "3" ]; then
      echo "NOTE: Analyzing both local and foreign addresses. See usage for more information."
    fi
    date
    echo ""
  fi

  NETSTAT=`netstat -an | grep tcp`

  i=0
  for PORT in ${PORTS[@]}
  do
    if [ "$OS" = "Linux" ]; then
      PORT=":$PORT\$"
    else # AIX, HP-UX
      PORT="\.$PORT\$"
    fi

    if [ "$SEARCH" -eq "1" ]; then
      AWKSEARCH='{print $4}'
      search
    elif [ "$SEARCH" -eq "2" ]; then
      AWKSEARCH='{print $5}'
      search
    elif [ "$SEARCH" -eq "3" ]; then
      AWKSEARCH='{print $4}'
      search
      AWKSEARCH='{print $5}'
      search
    fi

    i=$((i + 1));
  done

  TOTESTABLISHED=0
  TOTOPENING=0
  TOTCLOSING=0

  printf '%-6s %-12s %-8s %-8s\n' PORT ESTABLISHED OPENING CLOSING
  i=0
  PRINTED=0
  for PORT in ${PORTS[@]}
  do
    CNT=0
    CNT=$(($CNT + ${ESTABLISHED[$i]}));
    CNT=$(($CNT + ${OPENING[$i]}));
    CNT=$(($CNT + ${CLOSING[$i]}));
    DOPRINT=1
    if [ "$NONZERO" -eq "1" ]; then
      if [ "$CNT" -eq "0" ]; then
        DOPRINT=0
      fi
    fi
    if [ "$DOPRINT" -eq "1" ]; then
      printf '%-6s %-12s %-8s %-8s\n' $PORT ${ESTABLISHED[$i]} ${OPENING[$i]} ${CLOSING[$i]}
      PRINTED=$((PRINTED + 1));
    fi
    TOTESTABLISHED=$(($TOTESTABLISHED + ${ESTABLISHED[$i]}));
    TOTOPENING=$(($TOTOPENING + ${OPENING[$i]}));
    TOTCLOSING=$(($TOTCLOSING + ${CLOSING[$i]}));
    i=$((i + 1));
  done

  if [ "$NOTOTALS" -eq "0" ]; then
    if [ "$PRINTED" -ne "1" ]; then
      printf '%36s\n' | tr " " "="
      printf '%-6s %-12s %-8s %-8s\n' Total $TOTESTABLISHED $TOTOPENING $TOTCLOSING
    fi
  fi

else
  echo ""
  echo "ERROR: You must supply a list of one or more ports (space delimited)." >&2
  echo ""
  usage;
fi

