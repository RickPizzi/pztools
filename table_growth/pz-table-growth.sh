#!/bin/bash
#
#	statistics on table growth
#	rpizzi@blackbirdit.com
#
#
USER=growth
PASS='gr0wth!'
#
case "$1" in
	'size') type=1;;
	'percent') type=2;;
	'delta') type=3;;
	*) echo "usage: $0 [ size | percent | delta ]"; exit 1;;
esac
d7=$(echo "select id from growth where sample_date = date_sub(curdate(), interval 1 week) limit 1" | mysql -u$USER -p$PASS -ANr tablegrowth | wc -l)
d14=$(echo "select id from growth where sample_date = date_sub(curdate(), interval 2 week) limit 1" | mysql -u$USER -p$PASS -ANr tablegrowth | wc -l)
d30=$(echo "select id from growth where sample_date = date_sub(curdate(), interval 1 month) limit 1" | mysql -u$USER -p$PASS -ANr tablegrowth | wc -l)
echo
case $type in
	1) echo "Top 20 tables by disk usage in GB";;
	2) echo "Top 20 growing tables by percentage";;
	3) echo "Top 20 growing tables by GB";;
esac
echo
(
	echo "select "
	echo "	t0.server, t0.schema_name, t0.table_name, "
	if [ $d30 -eq 1 ]
	then
		case $type in
			1) echo -n "	t30.table_size";;
			2) echo -n "	concat(truncate(100 - (t30.table_size * 100 / t0.table_size),1), '%')";;
			3) echo -n "	t0.table_size - t30.table_size";;
		esac
	else
		echo -n "	'N/A'"
	fi
	echo " as 1_month, "
	if [ $d14 -eq 1 ]
	then
		case $type in
			1) echo -n "	t14.table_size";;
			2) echo -n "	concat(truncate(100 - (t14.table_size * 100 / t0.table_size),1), '%')";;
			3) echo -n "	t0.table_size - t14.table_size";;
		esac
	else
		echo -n "	'N/A'"
	fi
	echo " as 2_weeks, "
	if [ $d7 -eq 1 ]
	then
		case $type in
			1) echo -n "	t7.table_size" ;;
			2) echo -n "	concat(truncate(100 - (t7.table_size * 100 / t0.table_size),1), '%')";;
			3) echo -n "	t0.table_size - t7.table_size";;
		esac
	else
		echo -n "	'N/A'"
	fi
	echo " as 1_week, "
	case $type in
		1) echo "	t1.table_size as 1_day,";;
		2) echo "	concat(truncate(100 - (t1.table_size * 100 / t0.table_size), 1), '%') as 1_day";;
		3) echo "	t0.table_size - t1.table_size as 1_day";;
	esac
	case $type in
		1) echo "	t0.table_size as today ";;
	esac
	echo "from growth t0 "
	echo "	left join growth t1 on t1.server = t0.server and t1.schema_name = t0.schema_name and t1.table_name = t0.table_name "
	[ $d7 -eq 1 ] && echo "	left join growth t7 on t7.server = t0.server and t7.schema_name = t0.schema_name and t7.table_name = t0.table_name "
	[ $d14 -eq 1 ] && echo "	left join growth t14 on t14.server = t0.server and t14.schema_name = t0.schema_name and t14.table_name = t0.table_name "
	[ $d30 -eq 1 ] && echo "	left join growth t30 on t30.server = t0.server and t30.schema_name = t0.schema_name and t30.table_name = t0.table_name "
	echo "where "
		echo "	t1.sample_date =  date_sub(curdate(), interval 1 day) "
	[ $d7 -eq 1 ] && echo "	and t7.sample_date =  date_sub(curdate(), interval 1 week) "
	[ $d14 -eq 1 ] && echo "	and t14.sample_date =  date_sub(curdate(), interval 2 week) "
	[ $d30 -eq 1 ] && echo "	and t30.sample_date =  date_sub(curdate(), interval 1 month) "
	echo "	and t0.sample_date = curdate()"
	case $type in 
		2) echo "order by truncate(100 - (t1.table_size * 100 / t0.table_size), 1) desc limit 20;";;
		*) echo "order by 1_day desc limit 20;";;
	esac
) | mysql -u$USER -p$PASS -At tablegrowth
