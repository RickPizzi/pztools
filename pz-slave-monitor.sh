#!/bin/bash
#
#
#	pz-slave-monitor
#	monitor performances of SQL_thread and saves queries
#	longer than <min query time> in a file in the output folder
#
#	rick.pizzi@mariadb.com
#
#
DATADIR=/var/lib/mysql
FOLDER=./output
MIN_THRESHOLD=25 # milliseconds
#
[ ! -d $FOLDER ] && mkdir $FOLDER
if [ "$1" = "" ]
then
	echo "usage: $0 <min query time (ms)>"
	exit 1
fi
threshold=$1
if [ $threshold -lt $MIN_THRESHOLD ]
then
	echo "NOTE: Minimum query time is $MIN_THRESHOLD ms, adjusted accordingly"
	threshold=$MIN_THRESHOLD
fi
IFS="
"
start_ts=$(date +%s%N)
i=0
rbmsg=0
while true
do
	for sr in $(echo "show slave status\G" | mysql -Ar | egrep "Relay_Log_File|Relay_Log_Pos|Slave_SQL_Running")
	do
		r=${sr// /}
		case "${r%%:*}" in
			'Relay_Log_File') relay_file=${r#*:};;
			'Relay_Log_Pos') relay_pos=${r#*:};;
			'Slave_SQL_Running') running=${r#*:};;
		esac
	done
	if [ "$running" = "No" ]
	then
		if [ $rbmsg -eq 0 ]
		then
			echo -e "\rReplication broken, waiting"
			rbmsg=1
		fi
		sleep 5
		continue
	else
		[ "$running" = "" ] && break
		rbmsg=0
	fi
	if [ "$oldpos" != "$relay_file:$relay_pos" ]
	then
		diff=$((($(date +%s%N)-start_ts)/1000000))
		if [ $i -gt 1 -a $diff -ge $threshold ]
		then
			echo -e "\rExecuted $oldpos in $diff ms (loop time $(bc <<< "scale=1;$diff/$i") ms)"
			mysqlbinlog --base64-output=never -j ${oldpos#*:} $DATADIR/${oldpos%%:*} | egrep -v "^SET|^/\*!\*/;" | head -200 | fgrep -A 50 "# at ${oldpos#*:}" | grep -B 50 -m 1 "^COMMIT" > $FOLDER/${diff}_${oldpos%%:*}:${oldpos#*:} &
		fi
		oldpos="$relay_file:$relay_pos"
		start_ts=$(date +%s%N)	
		i=0
	fi
	i=$((i+1))
	echo -en "\r  $i "
done
