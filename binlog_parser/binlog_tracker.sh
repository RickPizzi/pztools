#!/bin/bash
#
#	tracks selected delete statements in binary logs, saving them in an auxiliary table 
#	should be run from crontab every 15 minutes or so. it relies on a small C program called binlog_parser
#	config file in /etc/binlog_parser.conf - see C program for more details
#
#	pizzi@leopardus.com
#
HOME=/localhome/dbadm
TRACKING_USER=delete_tracker
TRACKING_PASSWORD=tr4ck3r@BI
LOCKFILE=/tmp/binlog_tracker.pid


server_id=($(echo "show variables like 'server_id'" | mysql -Ar -f -u $TRACKING_USER -p$TRACKING_PASSWORD | grep server_id | awk '{print $2}'))

search_serverid="galeraserverid="$server_id
#echo "### $search_serverid"

trap 'rm -f $LOCKFILE' 0
#
if [ -f $LOCKFILE ]
then
	kill -0 $(cat $LOCKFILE) && exit 1 
fi
echo $$ > $LOCKFILE
watermark=$HOME/.deletetracker_watermark
[ ! -f $watermark ] && touch -d "1 year ago" $watermark
for binlog in $(find $(dirname $(grep ^log_bin /etc/my.cnf | cut -d"=" -f2)) -type f -name $(basename $(grep ^log_bin /etc/my.cnf | cut -d"=" -f2)).[0-9]\* ! -mmin -10 -newer $watermark -print | sort)
do
		echo "BEGIN;"
		mysqlbinlog --base64-output=decode-rows -vv $binlog | $HOME/bin/binlog_parser_new_row $(basename $binlog) | grep "$search_serverid"
		echo "COMMIT;"
	touch -r $binlog $watermark
done | tee /tmp/mysql_debug.log | mysql -A -f -u $TRACKING_USER -p$TRACKING_PASSWORD 2>/dev/null
exit 0
