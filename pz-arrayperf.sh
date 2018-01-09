#!/bin/bash
#
#	pz-arrayperf.sh - pretty prints storage statistics, autodetecting LVM layout
#
#	requires ioping, and is best used with "watch", as in "watch -n 1 ./pz-arrayperf.sh"
#	pizzi@leopardus.com
#
#
REQSIZE=16k # can override this on command line
#
IFS="
"
ovg=""
devlist=""
sg=0

list_devs()
{
	printf "%-16s %-24s %5s %5s %15s %9s %13s %13s %13s %13s %13s\n" "Volume Group" "Device" "Strip" "#req" "Time spent" "$REQSIZE IOPS" "xfer spd B/s" "min time (us)" "avg time (us)" "max time (us)" "stddev (us)"
	printf "%-16s %-24s %5s %5s %-15s %9s %11s %13s %13s %13s %13s\n" "----------------" "------------------------" "-----" "-----" "---------------" "-------" "-------------" "-------------" "-------------" "-------------" "-------------"
	sc=1
	for dev in $2
	do
		(
			IFS=" " 
			printf "%-16s %-24s %5s %5d %'15d %9d %'13d %'13d %'13d %'13d %'13d %.0s %.0s\n" $1 $dev "$sc/$3" $(ioping -D -B -q -i 0 -w 1 -S 64m -s $REQSIZE  $dev)
		) &
		sc=$((sc+1))
	done 
	wait
}

#(1) count of requests in statistics
#(2) running time (usec)
#(3) requests per second (iops)
#(4) transfer speed (bytes/sec)
#(5) minimal request time (usec)
#(6) average request time (usec)
#(7) maximum request time (usec)
#(8) request time standard deviation (usec)
#(9) total requests (including too slow and too fast)
#(10) total running time (usec)  

[ "$1" != "" ] && REQSIZE=$1
for d in $(lvs -o name,devices,stripes| fgrep -v "Device" | tr -s " " | tr " " "\t")
do
	vg=$(echo $d | cut -f 2)
	ss=$(echo $d | cut -f 4)
	devlist=$(echo $d | cut -f 3 | sed -e "s/([^)]*)//g" | tr "," "\n")
	list_devs $vg "$devlist" $ss
done
exit 0

