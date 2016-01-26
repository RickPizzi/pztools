#!/bin/bash
#
#	Nagios check for presence of MySQL partition for a given day in the future
#	riccardo.pizzi@rumbo.com
#	$1: schema, $2: table, $3: how many days in advance to check
#
USER=""
PASS=""
#
[ $# -ne 3 ] && exit 3
case $(echo "select concat('select if(',replace(replace(upper(substring_index(partition_expression, '(',1)), 'TO_DAYS', 'FROM_DAYS'), 'UNIX_TIMESTAMP', 'FROM_UNIXTIME'), '(', partition_description, ') > date_add(curdate(), interval $3 day), 0, 2)') from information_schema.partitions where table_schema = '$1' and table_name = '$2' order by partition_description desc limit 1" | /usr/bin/mysql -ANr -u $USER -p$PASS | /usr/bin/mysql -ANr -u $USER -p$PASS) in
	0) echo "OK: Partitions for next $3 days exist."; exit 0;;
	2) echo "CRITICAL: Not enough partitions for next $3 days!"; exit 2;;
	*) echo "UNKOWN"; exit 3;;
esac
