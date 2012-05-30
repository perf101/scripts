#!/bin/bash
#
# Title:             multi-iperf.sh
# Description:       A helper script for making parallel iperf sessions.
# Author:            Rok Strnisa <rok@strnisa.com>
# Source:            https://github.com/perf101/scripts

# FAIL IF ANY COMMAND FAILS
set -e

# DEFAULTS
aggregate=false
b_size=
out=
simple=false
threads=1
duration=5
verbose=false
declare -a vmips
vms=
w_size=
xentop_host=

# USAGE
basename=`basename ${0}`
usage_prefix="Usage: ${basename} "
indent=`printf "%${#usage_prefix}s" " "`
usage="${usage_prefix}[-h|--help] [-i <IP,IP,..>] [-n <INT>] [-t <INT>]
${indent}[-o <PATH>|--output <PATH>] [-P <INT>] [-x <HOST>]
${indent}[-b <INT>] [-w <INT>] [-f] [-v] [-a]

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
      Create <INT> Iperf threads per Iperf session. Default is ${threads}.

  -s
      Simple output. Only outputs the aggregate number (in Mbps). Implies -a.

  -t <INT>
      Set the test to last <INT> seconds. Default is ${duration}. Recommended
      is 60 or more.

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
    -a) aggregate=true;;
    -b) shift; b_size=${1};;
    -f) b_size=256; w_size=256;;
    -h | --help) echo "${usage}" | less -FX; exit;;
    -i) shift; IFS=',' read -ra vmips <<< "${1}";;
    -n) shift; vms=${1};;
    -o | --output) shift; out=${1};;
    -P) shift; threads=${1};;
    -s) aggregate=true; simple=true;;
    -t) shift; duration=${1};;
    -v) verbose=true;;
    -w) shift; w_size=${1};;
    -x) shift; xentop_host=${1};;
    *) echo "${usage}" | less -FX; exit 1
  esac
  shift
done

# FAIL IF A VARIABLE IS NOT SET
set -u

# VARIABLE CONSISTENCY CHECK AND POSTPROCESSING
if [ -z "${vms}" ]; then
  vms=${#vmips[@]}
fi
if [ ${vms} -gt ${#vmips[@]} ]; then
  echo "Error: # VMs (-n) is greater than # IPs (-VMIPs): ${vms} > ${#vmips[@]}."
  echo "See usage instructions with: $0 -h"
  exit 1
fi
if [ -n "${b_size}" ]; then
  b_size=" -l ${b_size}K"
fi
if [ -n "${w_size}" ]; then
  w_size=" -w ${w_size}K"
fi
xentop_out="${out}_xentop"

# START RECORDING XENTOP USAGE ON RECEIVER
if [ -n "${xentop_host}" ]; then
  if ${verbose}; then echo "Starting xentop logging for ${xentop_host} .."; fi
  ssh ${xentop_host} "xentop -b -d 1 -f" > "${xentop_out}" &
  pid=${!}
  if ${verbose}; then echo "Output file for xentop logging: ${xentop_out}"; fi
fi

# START PARALLEL IPERF SESSIONS
iperf_flags="${b_size}${w_size} -t ${duration} -P ${threads} -f m"
if ${verbose}; then echo "Using Iperf flags: ${iperf_flags}"; fi
tmp=`mktemp`
for i in `seq ${vms}`; do
  vm_ip=${vmips[i-1]}
  if ${verbose}; then echo "Connecting to ${vm_ip} .."; fi
  iperf -c ${vm_ip} ${iperf_flags} \
    | grep -v "SUM" \
    | grep -o "[0-9.]\+ Mbits/sec" \
    | awk -vIP=${vm_ip} '{print IP, $1}' \
    >> ${tmp} &
done

# WAIT FOR THE TESTS TO COMPLETE
sleep $((duration + 3))

# STOP RECORDING XENTOP USAGE
if [ -n "${xentop_host}" ]; then
  if ${verbose}; then echo "Stopping xentop logging for ${xentop_host} .."; fi
  kill ${pid};
fi

# SORT INDIVIDUAL RESULTS
tmp2=`mktemp`
if ! ${simple}; then sort -o ${tmp2} ${tmp}; fi

# OUTPUT AGGREGATE THROUGHPUT TO STDOUT
if ${aggregate}; then
  if ! ${simple}; then echo -n "AGGREGATE " >> ${tmp2}; fi
  cat "${tmp}" | awk '{sum+=$2}END{print sum}' >> ${tmp2}
fi

# OUTPUT RESULTS
if [ -n "${out}" ]; then
  cp ${tmp2} ${out}
else
  cat ${tmp2}
fi

# REMOVE TEMPORARY FILES
rm -f ${tmp} ${tmp2}
