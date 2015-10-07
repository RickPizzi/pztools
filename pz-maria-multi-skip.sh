#!/bin/bash
#
# auto-skip statements on selected slave in a multi source replication env
# args: 
#	$1 => master connection to use for skipping
#
[ "$1" = "" ] && exit 1
echo -n "Password: "
stty -echo
read password
stty echo
echo
pc=$(mysqladmin --protocol=tcp -p$password ping | fgrep -c alive)
[ $pc -ne 1 ] && exit 1
while true
do
	status=$(echo "show slave '$1' status\G" | mysql -Ar -p$password 2>/dev/null | egrep "Seconds_Behind_Master:|Slave_IO_Running:" | tr -d "[ ]" | tr -s "[\n]" "[:]")
	iothread=$(echo "$status" | cut -d ":" -f 2)
	behind=$(echo "$status" | cut -d":" -f 4)
	if [ "$iothread" != "Yes" ]
	then
		sleep 0.05
		continue
	fi
	if [ "$behind" = "NULL" ]
	then
		echo -n "." 
		echo "set session default_master_connection='$1'; stop slave; set global sql_slave_skip_counter = 1; start slave" | mysql -ANr -p$password 2>/dev/null
	else
		if [ $behind -eq 0 ] 
		then
			echo "Slave '$1' is caught up"
			sleep 58
		else
			echo $behind
		fi
		sleep 2
	fi
done
