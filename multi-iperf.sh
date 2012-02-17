#!/bin/bash
#
# Title:             multi-iperf.sh
# Description:       A helper script for making parallel iperf sessions.
# Author:            Rok Strnisa <rok@strnisa.com>
# Source:            https://github.com/perf101/scripts

# FAIL IF ANY COMMAND FAILS
set -e

# DEFAULTS
AGGREGATE=false
BASENAME=`basename ${0}`
B_SIZE=
OUT=
SIMPLE=false
THREADS=1
TIME=5
VERBOSE=false
declare -a VMIPs
VMS=
W_SIZE=
XENTOP_HOST=

# USAGE
USAGE_PREFIX="Usage: ${BASENAME} "
INDENT=`printf "%${#USAGE_PREFIX}s" " "`
USAGE="${USAGE_PREFIX}[-h|--help] [-i <IP,IP,..>] [-n <INT>] [-t <INT>] 
${INDENT}[-o <PATH>|--output <PATH>] [-P <INT>] [-x <HOST>]
${INDENT}[-b <INT>] [-w <INT>] [-f] [-v] [-a]

  -a
      Output aggregate network throughput (in Mbps) to standard output.

  -b <INT>
      Iperf buffer size in KB to use. The receiving side should probably use
      the same buffer size. Default depends on your Iperf implementation and
      your system.

  -f
      Fix Iperf buffer size (-b) and window size (-w) to 256KB. Recommended
      when sending traffic to Windows VMs. (Iperfs on those VMs should
      probably use the same buffer and window size.)

  -h, --help
      Show usage instructions.

  -i <IP,IP,..>
      A comma-separated list of VM IPs. Used for establishing Iperf sessions
      with the VMs. The number of IPs must be equal or greater than the number
      specified for -n. No default.

  -n <INT>
      Create concurrent Iperf sessions with <INT> VMs. Must be smaller than or
      equal to the number of IPs specified in -i. Default is the number of IPs
      specified with -i.

  -o <PATH>, --output <PATH>
      Save results (in Mbps) into the file at <PATH> instead of outputting
      them to standard output.

  -P <INT>
      Create <INT> Iperf threads per Iperf session. Default is ${THREADS}.

  -s
      Simple output. Only outputs the aggregate number (in Mbps). Implies -a.

  -t <INT>
      Set the test to last <INT> seconds. Default is ${TIME}. Recommended is
      60 or more.

  -v
      Verbose. At the moment, this only shows the final Iperf configuration.

  -w <INT>
      Iperf window size in KB to use. The receiving side should probably use
      the same window size. Default depends on your Iperf implementation and
      your system.

  -x <HOST>
      Specify a <HOST> (any address reachable via SSH without user interaction)
      for which to track CPU usage via xentop. The resolution is one xentop
      snapshot per second. The output is stored in _xentop, or <PATH>_xentop
      where <PATH> is the argument for -o.
"

# OVERRIDE DEFAULTS WITH ARGUMENTS
while [ -n "${1}" ]; do
  case ${1} in
    -a) AGGREGATE=true;;
    -b) shift; B_SIZE=${1};;
    -f) B_SIZE=256; W_SIZE=256;;
    -h | --help) echo "${USAGE}" | less -FX; exit;;
    -i) shift; IFS=',' read -ra VMIPs <<< "${1}";;
    -n) shift; VMS=${1};;
    -o | --output) shift; OUT=${1};;
    -P) shift; THREADS=${1};;
    -s) AGGREGATE=true; SIMPLE=true;;
    -t) shift; TIME=${1};;
    -v) VERBOSE=true;;
    -w) shift; W_SIZE=${1};;
    -x) shift; XENTOP_HOST=${1};;
    *) echo "${USAGE}" | less -FX; exit 1
  esac
  shift
done

# FAIL IF A VARIABLE IS NOT SET
set -u

# VARIABLE CONSISTENCY CHECK AND POSTPROCESSING
if [ -z "${VMS}" ]; then
  VMS=${#VMIPs[@]}
fi
if [ ${VMS} -gt ${#VMIPs[@]} ]; then
  echo "Error: # VMs (-n) is greater than # IPs (-VMIPs): ${VMS} > ${#VMIPs[@]}."
  echo "See usage instructions with: $0 -h"
  exit 1
fi
if [ -n "${B_SIZE}" ]; then
  B_SIZE=" -l ${B_SIZE}K"
fi
if [ -n "${W_SIZE}" ]; then
  W_SIZE=" -w ${W_SIZE}K"
fi
XENTOP_OUT="${OUT}_xentop"

# START RECORDING XENTOP USAGE ON RECEIVER
if [ -n "${XENTOP_HOST}" ]; then
  if ${VERBOSE}; then echo "Starting xentop logging for ${XENTOP_HOST} .."; fi
  ssh ${XENTOP_HOST} "xentop -b -d 1 -f" > "${XENTOP_OUT}" &
  PID=${!}
  if ${VERBOSE}; then echo "Output file for xentop logging: ${XENTOP_OUT}"; fi
fi

# START PARALLEL IPERF SESSIONS
IPERF_CMD="iperf${B_SIZE}${W_SIZE} -t ${TIME} -P ${THREADS}"
if ${VERBOSE}; then echo "Using Iperf command: ${IPERF_CMD}"; fi
TMP=`mktemp`
for i in `seq ${VMS}`; do
  VM_IP=${VMIPs[i-1]}
  if ${VERBOSE}; then echo "Connecting to ${VM_IP} .."; fi
  ${IPERF_CMD} -c ${VM_IP} -f m \
    | grep -o "[0-9.]\+ Mbits/sec" \
    | awk -vIP=${VM_IP} '{print IP, $1}' \
    >> ${TMP} &
done

# WAIT FOR THE TESTS TO COMPLETE
sleep $((TIME + 3))

# STOP RECORDING XENTOP USAGE
if [ -n "${XENTOP_HOST}" ]; then
  if ${VERBOSE}; then echo "Stopping xentop logging for ${XENTOP_HOST} .."; fi
  kill ${PID};
fi

# SORT INDIVIDUAL RESULTS
TMP2=`mktemp`
if ! ${SIMPLE}; then sort -o ${TMP2} ${TMP}; fi

# OUTPUT AGGREGATE THROUGHPUT TO STDOUT
if ${AGGREGATE}; then
  if ! ${SIMPLE}; then echo -n "AGGREGATE " >> ${TMP2}; fi
  cat "${TMP}" | awk '{sum+=$2}END{print sum}' >> ${TMP2}
fi

# OUTPUT RESULTS
if [ -n "${OUT}" ]; then
  cp ${TMP2} ${OUT}
else
  cat ${TMP2}
fi

# REMOVE TEMPORARY FILES
rm -f ${TMP} ${TMP2}
