!/bin/bash
#
#
#	takes a sample of SHOW ENGINE INNODB STATUS every $SLEEP seconds and stores it in files
#	under $SAMPLEDIR for later use
#	(run it in background with nohup)
#	rpizzi@blackbirdit.com
#
SAMPLEDIR=/mnt/log/samples
HOSTS="server1:10.77.23.111 server2:10.77.44.22"
SLEEP=10
#
c=0
ts=$(date +%H%M)
while true
do
	month=$(date +%m)
	day=$(date +%d)
	for host in $HOSTS
	do
		hour=$(date +%H)
		name=$(echo $host | cut -d":" -f 1)
		addr=$(echo $host | cut -d":" -f 2)
		folder=$SAMPLEDIR/$month/$day
		[ ! -d $folder ] && mkdir -p $folder
		echo "show engine innodb status" | mysql -r -h $addr >> $folder/${name}_${hour}.sample
	done
	wait
	sleep $SLEEP
done
