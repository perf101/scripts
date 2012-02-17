#!/bin/bash
#
# Title:             exclusive-pin.sh
# Description:       A helper script for putting dom0 on exclusive CPUs.
# Author:            Rok Strnisa <rok@strnisa.com>
# Source:            https://github.com/perf101/scripts

# FAIL IF ANY COMMAND FAILS
set -e

# DEFAULTS
EXEC="eval"

# USAGE
BASENAME=`basename ${0}`
USAGE_PREFIX="Usage: ${BASENAME} "
INDENT=`printf "%${#USAGE_PREFIX}s" " "`
USAGE="${USAGE_PREFIX}[-h|--help] [-n|--dry-run]

  -h
      Show usage instructions.

  -n, --dry-run
      Dry run. Only output the commands that would be executed.
"

# OVERRIDE DEFAULTS WITH ARGUMENTS
while [ -n "${1}" ]; do
  case ${1} in
    -h | --help) echo "${USAGE}" | less -FX; exit;;
    -n | --dry-run) EXEC="echo";;
    *) echo "${USAGE}" | less -FX; exit 1
  esac
  shift
done

# FAIL IF VARIABLE IS NOT SET
set -u

# OBTAIN THE NUMBER OF DOM0 VCPUS
DOM0_VCPUS=`ls -d /sys/devices/system/cpu/cpu* | wc -l`

# PIN DOM0 VCPUS TO INITIAL PHYSICAL CPUS
for v in `seq 0 $((DOM0_VCPUS - 1))`; do
  ${EXEC} "xl vcpu-pin 0 ${v} ${v}"
done

# OBTAIN THE NUMBER OF ALL PHYSICAL CPUS
DOM0_UUID=`awk -F\' '/^INSTALLATION_UUID/ {print $2}' /etc/xensource-inventory`
ALL_VCPUS=`xe host-cpu-list --minimal host-uuid=${DOM0_UUID} | sed 's/,/ /g' | wc -w`

# OBTAIN DOM ID TO DOM UUID MAPPING
ID_UUIDS=`list_domains | awk '{if ($1 != "id" && $1 != "0") print $1,$3}'`

# FOR EACH ONLINE USER DOMAIN
for id_uuid in "${ID_UUIDS}"; do
  declare -a ids
  IFS=' ' read -ra ids <<< "${id_uuid}"
  if [ ${#ids[@]} == 0 ]; then continue; fi
  # OBTAIN THE NUMBER OF ITS VCPUS
  VCPUS=`xe vm-param-get uuid=${ids[1]} param-name=VCPUs-number`
  # AND PIN THEM TO NON-DOM0 PHYSICAL CPUS
  for v in `seq 0 $((VCPUS - 1))`; do
    ${EXEC} "xl vcpu-pin ${ids[0]} ${v} ${DOM0_VCPUS}-$((ALL_VCPUS - 1))"
  done
done
