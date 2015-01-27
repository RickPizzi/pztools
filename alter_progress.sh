#!/bin/bash
#
#	script that detects an ALTER table being executed by the replication SQL thread
#	and prints a pretty progress bar with an ETA every minute
#	riccardo.pizzi@rumbo.com
#
echo -n "Password: "
stty -echo
read password
stty echo
echo
table=$(echo "select concat(db, '.', substring_index(substring_index(info, ' ', -4), ' ', 1)) from processlist where left(info, 5) = 'alter'" | mysql -ANr -p$password information_schema) 
if [ "$table" = "" ]
then
	echo "No alter table coming via replication at this time. Exiting."
	exit 1
fi
echo -n "Counting rows in $table, please stand by... "
count=$(echo "select count(*) from $table" | mysql -ANr -p$password)
echo "done."
prev_rows=0
left=0
while true
do
	rows=$(echo "select rows_read from information_schema.processlist where left(info, 5) = 'alter'" | mysql -ANr -p$password)
	[ "$rows" = "" ] && break
	perc=$(printf "%2.2f\n" $(echo "scale=4; $rows / $count * 100" | bc))
	if [ $prev_rows -gt 0 ]
	then
		rows_done=$(($rows - $prev_rows))
		left=$(echo "scale=2; ($count - $rows) / $rows_done * 60" | bc)
	fi
	prev_rows=$rows
	echo "select '  5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100' as progress union select concat(if($perc > 5, 'XXX', '___'), if($perc > 10, 'XXX', '___'), if($perc > 15, 'XXX', '___'), if($perc > 20, 'XXX', '___'), if($perc > 25, 'XXX', '___'), if($perc > 30, 'XXX', '___'), if($perc > 35, 'XXX', '___'), if($perc > 40, 'XXX', '___'), if($perc > 45, 'XXX', '___'), if($perc > 50, 'XXX', '___'), if($perc > 55, 'XXX', '___'), if($perc > 60, 'XXX', '___'), if($perc > 65, 'XXX', '___'), if($perc > 70, 'XXX', '___'), if($perc > 75, 'XXX', '___'), if($perc > 80, 'XXX', '___'), if($perc > 85, 'XXX', '___'), if($perc > 90, 'XXX', '___'), if($perc > 95, 'XXX', '___'), '____   ', $perc, '%  ETA: ', IF($left > 0, SEC_TO_TIME($left), '--'))" | mysql -ANr -p$password
	sleep 60
done
echo "ALTER is over."
exit 0
