#!/bin/bash
#
# 	script to move from master to the passive master 
#	WARNING: it assumes all slaves caught up!!
#	rpizzi@blackbirdit.com
#
#	Config file:
#	master=1.2.3.4
#	comaster=1.2.3.5
#	slaves=1.2.1.1 1.2.1.2 ....
#
USER=root
PASSWORD=
#
tmpf=/tmp/remaster.$$
trap 'rm -f $tmpf' 0
master=$(grep ^master Config | cut -d"=" -f2)
new_master=$(grep ^comaster Config | cut -d"=" -f2)
slaves=$(grep ^slaves Config | cut -d"=" -f2)
#
echo -n "setting master $master read only... "
echo "set global read_only=1" | mysql -u$USER -p$PASSWORD -h $master
ro=$(echo "show variables like 'read_only'" | mysql -u$USER -p$PASSWORD -ANr -h $master | cut -f 2)
if [ "$ro" = "ON" ]
then
	echo OK
else
	echo "FAILED, but continuing"
fi
echo -n "getting master status from new master $new_master... "
status=$(echo "show master status" | mysql -u$USER -p$PASSWORD -ANr -h $new_master)
master_log_file=$(echo "$status" | cut -f 1)
master_log_pos=$(echo "$status" | cut -f 2)
if [ "$master_log_file" = "" -o "$master_log_pos" = "" ]
then
	echo "FAILED"
	exit 1
else
	echo "OK    ($master_log_file, position $master_log_pos)"
fi
echo -n "resetting slave status on new master... "
echo "stop slave; reset slave all" | mysql -u$USER -p$PASSWORD -ANr -h $new_master
sc=$(echo "show slave status" | mysql -u$USER -p$PASSWORD -ANr -h $new_master | wc -c)
if [ $sc  -eq 0 ]
then
	echo "OK"
else
	echo "FAILED"
	exit 1
fi
echo -n "setting new master $new_master read write... "
echo "set global read_only=0" | mysql -u$USER -p$PASSWORD -h $new_master
ro=$(echo "show variables like 'read_only'" | mysql -u$USER -p$PASSWORD -ANr -h $new_master | cut -f 2)
if [ "$ro" = "OFF" ]
then
	echo OK
else
	echo "FAILED"
	exit 1
fi
for slave in $slaves
do
	echo -n "changing master of slave $slave... "
	echo "stop slave; change master to master_host = '$new_master', master_log_file = '$master_log_file', master_log_pos = $master_log_pos; start slave"  | mysql -u$USER -p$PASSWORD -h $slave
	echo "show slave status\G" | mysql -u$USER -p$PASSWORD -Ar  -h $slave | egrep "Master_Host:|Slave_IO_Running:|Slave_SQL_Running:" | tr -d "[ ]" > $tmpf
	check=$(grep "Master_Host" $tmpf | cut -d":" -f 2)
	if [ "$check" != "$new_master" ]
	then
		echo "FAILED - fix manually"
		continue
	fi
	check=$(grep "Slave_IO_Running" $tmpf | cut -d":" -f 2)
	if [ "$check" != "Yes" ]
	then
		echo "FAILED - fix manually"
		continue
	fi
	check=$(grep "Slave_SQL_Running" $tmpf | cut -d":" -f 2)
	if [ "$check" != "Yes" ]
	then
		echo "FAILED - fix manually"
		continue
	fi
	echo "OK"
done
echo "Now entering slave replication check loop."
echo "Interrupt with Ctrl-C when you're bored."
while true
do
	for slave in $slaves
	do
		echo -n $slave" ... "
		echo "show slave status\G" | mysql -u$USER -p$PASSWORD -Ar -h $slave | fgrep Seconds
	done
	sleep 5
done
