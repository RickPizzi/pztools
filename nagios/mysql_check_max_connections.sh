#!/bin/bash
#
#	Nagios check if max_connections limit is close or reached
#	riccardo.pizzi@rumbo.com
#	Note: MySQL user needs RELOAD privs from localhost
#
USER=""
PASS=""
THRESHOLD=20
#
limit=$(echo "show variables like 'max_connections'" | /usr/bin/mysql -ANr -u $USER -p$PASS 2>/dev/null | cut -f 2)
max=$(echo "show global status like 'Max_used_connections'" | /usr/bin/mysql -ANr -u $USER -p$PASS 2>/dev/null | cut -f 2)
wt=$(($limit*(100-$THRESHOLD)/100))
if [ $max -ge $limit ]
then
	echo "CRITICAL: 100% of available connections in use ($max)"
	echo "FLUSH STATUS" | /usr/bin/mysql -ANr -u $USER -p$PASS 2>/dev/null
	exit 2
fi
if [ $max -ge $wt ]
then
	echo "WARNING: more than $((100-$THRESHOLD))% of available connections in use ($max/$limit)"
	echo "FLUSH STATUS" | /usr/bin/mysql -ANr -u $USER -p$PASS 2>/dev/null
	exit 1
fi
echo "OK: max used connections $max ($(echo "scale=2;$max/$limit*100" | bc | cut -d"." -f 1)%)"
exit 0
