#!/bin/bash
#
#
#	takes a sample of SHOW ENGINE INNODB STATUS every 10 seconds and stores it in files
#	under $SAMPLEDIR for later use
#	(run it in background with nohup; user should have password in dot file)
#	get_reply routine only needed to drain the mysql output pipe otherwise script will block when it fills up
#	rpizzi@blackbirdit.com
#
SAMPLEDIR=$HOME/sampling/data/$(hostname)
USER=photographer
#
get_reply()
{
 	while read -t 0.2 -u ${mysqlc[0]} row
        do
		echo "$row" >/dev/null
	done
}

coproc mysqlc { script -c "mysql -ANrs -u$USER 2>&1" /dev/null; }
c=0
echo "set session interactive_timeout=30;" >&${mysqlc[1]}
echo "set session wait_timeout=30;" >&${mysqlc[1]}
while true
do
	month=$(date +%m)
	day=$(date +%d)
	hour=$(date +%H)
	folder=$SAMPLEDIR/$month/$day
	[ ! -d $folder ] && mkdir -p $folder
	echo "pager cat >> $folder/$hour.sample" >&${mysqlc[1]}
	echo "show engine innodb status;" >&${mysqlc[1]}
	get_reply
	sleep 10
done
