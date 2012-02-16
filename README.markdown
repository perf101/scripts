## Description

A collection of performance-related scripts used by
[perf101](https://github.com/perf101).

## Scripts

### The `multi-iperf.sh` script

[`multi-iperf.sh`](https://github.com/perf101/scripts/blob/master/multi-iperf.sh)
is a helper script for making parallel [`iperf`](http://iperf.sourceforge.net/)
sessions to multiple destinations. It can also track CPU usage of a (possibly
remote) host via `xentop`. For all options, type `./multi-iperf.sh -h`.

    $ ./multi-iperf.sh -i 10.1.2.110,10.1.2.111 -a
    10.1.2.110 931
    10.1.2.111 937
    AGGREGATE 1868

### The `stats` script

[`stats`](https://github.com/perf101/scripts/blob/master/stats) is used for
statistical analyses of streams of numbers. The script is intentionally written
in AWK, since it is one of the very few omnipresent tools that can deal with
floating-point numbers.

    $ cat data
    737.267
    743.735
    688.51
    737.488
    ...
    
    $ cat data | awk -f stats
    LEGEND:
      n = Sample Number
      m = Mean
      s = Standard Deviation
      r = Relative Standard Error
      v = Nth Value
    STREAM:
    n =       1, m =    737.27, s =      0.00, r =  0.00%, v = 737.267
    n =       2, m =    740.50, s =      3.23, r =  0.31%, v = 743.735
    n =       3, m =    723.17, s =     24.65, r =  1.97%, v =  688.51
    n =       4, m =    726.75, s =     22.23, r =  1.53%, v = 737.488
    ...
