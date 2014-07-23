#!/bin/bash
#
#	reads entire device in order to warm it up (useful for EC2 EBS volumes)
#	pretty prints progress as it goes. to be run in a screen session!
#
#	rpizzi@blackbirdit.com
#
tmpf=/tmp/pzdd.$$
if [ $# -ne 1 ]
then
	echo "Usage: $0 <device>"
	exit 1
fi
if [ ! -b $1 ]
then
	echo "$1 non existent or invalid device"
	exit 1
fi
echo "Launching: dd if=$1 of=/dev/null bs=1024k"
dd if=$1 of=/dev/null bs=1024k 2>$tmpf &
pid=$!
trap 'rm -f $tmpf; kill $pid' 0
echo "dd process id $pid"
sleep 3
while true
do
	kill -0 $pid 2>/dev/null || break
	kill -SIGUSR1 $pid
	sleep 1
	echo -n "$(date '+%Y-%m-%d %T ')"
	tail -1 $tmpf
	sleep 59
done
echo "Completed."
exit 0
