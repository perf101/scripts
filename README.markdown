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
statistical analyses of streams of (floating-point) numbers. The script is
intentionally written in AWK, since it has wide-spread support, and is
commonly installed by default.

    $ cat data
    737
    743
    688
    737
    ...
    
    $ cat data | awk -f stats
    LEGEND:
      n = Sample Number
      m = Mean
      s = Standard Deviation
      r = Relative Standard Error
      v = Nth Value
    STREAM:
    n =       1, m =    737.00, s =      0.00, r =  0.00%, v =     737
    n =       2, m =    740.00, s =      3.00, r =  0.29%, v =     743
    n =       3, m =    722.67, s =     24.64, r =  1.97%, v =     688
    n =       4, m =    726.25, s =     22.22, r =  1.53%, v =     737
    ...
