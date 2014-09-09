#!/bin/bash
#
#	looks for a running pt-online-schema-change process and throttles it so that
#	no node of cluster has more than MAX_LATENCY replication latency
#	rpizzi@blackbirdit.com
#
MAX_LATENCY=600
#
pid=$(ps -eAo pid,args | fgrep pt-online-schema-change | grep -v grep | tr -s "[ ]" | sed -e "s/^ //g" | cut -d" " -f 1)
if [ "$pid" = "" ]
then
	echo "nothing to babysit"
	exit 1
fi
running=1
while true
do
	kill -0 $pid 2>/dev/null || break
	latency=$(echo ls | su - tungsten -c cctrl | fgrep -i latency | tr -d "[)|]"  | cut -d"=" -f 2 | cut -d"." -f 1 | sort -nrk 1 | head -1)
	if [ $latency -gt $MAX_LATENCY ]
	then
		if [ $running -eq 1 ]
		then
			kill -STOP $pid
			[ $? -ne 0 ] && break
			running=0
		fi
		echo "Paused: latency $latency > $MAX_LATENCY"
	else
		if [ $running -eq 0 ]
		then
			kill -CONT $pid
			[ $? -ne 0 ] && break
			running=1
			echo "Resumed: latency $latency < $MAX_LATENCY"
		else
			echo "Running: latency $latency" 
		fi
	fi
	sleep 15
done
echo "Done"
exit 0
