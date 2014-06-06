#!/bin/bash
#
#	create list of all schemas and their monthly growth
#	rpizzi@blackbirdit.com
echo
echo "database growth in the last 30 days, in GB"
echo
(
	echo "select db_schema, db_growth from ("
	c=0
	for schema in $(echo "select distinct schema_name from growth" | mysql -ANr tablegrowth)
	do 
		[ $c -gt 0 ] && echo "union "
		echo "select '$schema' as db_schema, sum(table_size) as db_growth from ((select sum(table_size) as table_size  from growth where schema_name = '$schema' and sample_date >= date_sub(curdate(), interval 1 month) group by sample_date order by sample_date desc limit 1) union (select -sum(table_size) as table_size  from growth where schema_name = '$schema' and sample_date >= date_sub(curdate(), interval 1 month) group by sample_date order by sample_date limit 1))d " 
		c=$(expr $c + 1)
	done 
	echo ") d order by db_growth desc" 
) | mysql -At tablegrowth
exit 0
