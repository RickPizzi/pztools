#!/bin/bash
#
#
#	takes a sample of SHOW ENGINE INNODB STATUS every 10 seconds and stores it in files
#	under $SAMPLEDIR for later use
#	(run it in background with nohup)
#	v2.0 	use coprocess and permanent connection to server
#	riccardo.pizzi@rumbo.com
#
SAMPLEDIR=$HOME/sampling/data/$(hostname)
SAMPLEFILE=/tmp/sampler.sample
#
echo -n "Password: "
stty -echo
read pass
stty echo
echo
coproc mysqlc { script -c "mysql -ANrs -p$pass 2>/dev/null" /dev/null; }
c=0
while true
do
	month=$(date +%m)
	day=$(date +%d)
	hour=$(date +%H)
	folder=$SAMPLEDIR/$month/$day
	[ ! -d $folder ] && mkdir -p $folder
	echo "pager cat >> $folder/$hour.sample" >&${mysqlc[1]}
	echo "show engine innodb status;" >&${mysqlc[1]}
	sleep 10
done

