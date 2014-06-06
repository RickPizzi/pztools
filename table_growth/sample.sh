#!/bin/bash
#
#	populates table growth DB from selected slaves
#	rpizzi@blackbirdit.com
#
SERVERS="10.77.24.11 10.77.25.134 10.77.25.147 10.77.25.104 10.77.24.138 10.77.25.34"
EXCLUDE="pdb palomino percona information_schema performance_schema mysql"
#
c=0
for e in $EXCLUDE
do
	[ $c -gt 0 ] && exclude="$exclude, "
	exclude="$exclude'$e'"
	c=$(expr $c + 1)
done
for server in $SERVERS
do
	echo "select concat('insert into growth values (null, \'', sample_date, '\', \'$server\', \'', table_schema, '\', \'', table_name, '\',' , gb_used, ');') from (select curdate() as sample_date, table_schema, table_name, (data_length+ index_length) / 1073741824  as gb_used from tables where table_schema not in ($exclude)) d" | mysql -h $server -AN information_schema | mysql -A -u growth -p'gr0wth!' tablegrowth
done
exit 0
