#!/bin/bash
#
# Title:             compare-results.sh
# Description:       A helper script for percentage comparison of two values.
# Author:            Rok Strnisa <rok@strnisa.com>
# Source:            https://github.com/perf101/scripts

# FAIL IF ANY COMMAND FAILS OR IF A VARIABLE IS NOT SET
set -e -u

# THE TWO VALUES PASSED IN
a=$1
b=$2

# A HELPER FUNCTION TO PERFORM AND PRINT THE COMPARISON
function compare_values() {
  x_name=$1; y_name=$2; x_val=$3; y_val=$4;
  result=`echo "scale=10; 100.0 * ($y_val - $x_val) / $x_val" | bc`
  printf "(%s - %s) / %s = %0.2f%%\n" $y_name $x_name $x_name $result
}

# USER-FRIENDLY OUTPUT
echo "==================="
echo "a = $a"
echo "b = $b"
echo "==================="
compare_values a b $a $b
compare_values b a $b $a
echo "==================="
