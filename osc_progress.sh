#!/bin/bash
#
#	shows real progress of an online schema change session
#	when PK is a numeric autoinc column
#	uses current user to log to the DB; you can specify the user running the OSC as an argument
#	if different than the user running this script (eg. if you want to run this on a slave)
#	rpizzi@blackbirdit.com
#
echo -n "MySQL Password: "
stty -echo
read PASS
stty echo
echo
mysqladmin -u $USER -p$PASS ping 2>/dev/null | fgrep -q alive
if [ $? -ne 0 ]
then
	echo "invalid password"
	exit 1
fi
[ "$1" != "" ] && OSC_USER=$1 || OSC_USER=$USER
#
echo -n "Getting OSC information... "
while true
do
	row=$(echo "select * from information_schema.processlist where user = '"$OSC_USER"' and info like 'INSERT LOW%'" | mysql -AN -u $USER -p$PASS | sed -e "s/\`//g")
	[ "$row" != "" ] && break
	sleep 1
done
echo "done."
table=$(echo $row | grep -oP '(?<=FROM\s)\w+\.\w+')
table_schema=$(echo $table | cut -d"." -f1)
table_name=$(echo $table | cut -d"." -f2)
pk=$(echo $row | grep -oP '(?<=WHERE\s\(\()\w+')
coltype=$(echo "select data_type from information_schema.columns where table_schema = '"$table_schema"' and table_name = '"$table_name"' and column_name = '"$pk"'" | mysql -AN -u $USER -p$PASS)
case "$coltype" in
	'int'|'bigint') ;;
	*) echo "sorry, this script only works when PK is an integer"; exit 1;;
esac
target=$(echo "select $pk from $table order by 1 desc limit 1" | mysql -AN -u $USER -p$PASS)
while true
do
	curr=$(echo "select * from information_schema.processlist where user = '"$OSC_USER"' and info like 'INSERT LOW%'" | mysql -AN -u $USER -p$PASS | sed -e "s/\`//g" | grep -oP '(?<=\s\<\=\s.)\w+')
	if [ "$curr" = "" ]
	then
		sleep 2
	else
		perc=$(echo "scale=4; $curr / $target *100" | bc)
		/usr/bin/printf "%s: %s/%s (%.2f%%)\n" $table $curr $target $perc
		sleep 30
	fi
done
exit 0
