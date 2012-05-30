#!/bin/bash
#
# Title:             exclusive-pin.sh
# Description:       A helper script for putting dom0 on exclusive CPUs.
# Author:            Rok Strnisa <rok@strnisa.com>
# Author:            Marcus Granado <marcus.granado@citrix.com>
# Source:            https://github.com/perf101/scripts

# FAIL IF ANY COMMAND FAILS
set -e

# DEFAULTS
# execution mode
mode="eval"

# USAGE
basename=`basename ${0}`
usage_prefix="Usage: ${basename} "
indent=`printf "%${#usage_prefix}s" " "`
persistent=
usage="${usage_prefix}[-h|--help] [-n|--dry-run]

  -h
      Show usage instructions.

  -n, --dry-run
      Dry run. Only output the commands that would be executed.

  -p, --persistent
      Make the modifications persistent across reboots.
"

# OVERRIDE DEFAULTS WITH ARGUMENTS
while [ -n "${1}" ]; do
  case ${1} in
    -h | --help) echo "${usage}" | less -FX; exit;;
    -n | --dry-run) mode="echo";;
    -p | --persistent) persistent="yes";;
    *) echo "${usage}" | less -FX; exit 1
  esac
  shift
done

# FAIL IF VARIABLE IS NOT SET
set -u

# OBTAIN THE NUMBER OF DOM0 VCPUS
dom0_vcpus=`ls -d /sys/devices/system/cpu/cpu* | wc -l`

# PIN DOM0 VCPUS TO INITIAL PHYSICAL CPUS
for v in `seq 0 $((dom0_vcpus - 1))`; do
  ${mode} "xl vcpu-pin 0 ${v} ${v}"
done

# OBTAIN THE NUMBER OF ALL PHYSICAL CPUS
dom0_uuid=`awk -F\' '/^INSTALLATION_UUID/ {print $2}' /etc/xensource-inventory`
all_vcpus=`xe host-cpu-list --minimal host-uuid=${dom0_uuid} | sed 's/,/ /g' | wc -w`

# OBTAIN DOM ID TO DOM UUID MAPPING
id_uuids=`list_domains | awk '{if ($1 != "id" && $1 != "0") print $1,$3}'`

# FOR EACH ONLINE USER DOMAIN
for id_uuid in "${id_uuids}"; do
  declare -a ids
  IFS=' ' read -ra ids <<< "${id_uuid}"
  if [ ${#ids[@]} == 0 ]; then continue; fi
  # OBTAIN THE NUMBER OF ITS VCPUS
  vcpus=`xe vm-param-get uuid=${ids[1]} param-name=VCPUs-number`
  # AND PIN THEM TO NON-DOM0 PHYSICAL CPUS
  for v in `seq 0 $((vcpus - 1))`; do
    ${mode} "xl vcpu-pin ${ids[0]} ${v} ${dom0_vcpus}-$((all_vcpus - 1))"
  done
done

if [ ! -z $persistent ]; then
  # PERSIST VCPU PIN SETTINGS OF VMS
  vm_uuids=`xe vm-list is-control-domain=false --minimal | sed 's/,/ /g'`
  non_dom0_pcpus=`seq ${dom0_vcpus} $((all_vcpus - 1)) |tr '\n' ','|sed 's/,$//'`
  for vm_uuid in $vm_uuids; do
    ${mode} "xe vm-param-set uuid=$vm_uuid VCPUs-params:mask=${non_dom0_pcpus}"
  done
fi
