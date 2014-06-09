#!/bin/bash
# script is using SELECT COUNT(*) to read top 10 tables on the server
# will not work with MyISAM
# (c) Vlad Fedorkov 2012, exclusive for PalominoDB 
# (c) converted to bash from PHP by rpizzi@palominodb.com
#
[ $# -ne 3 ] && echo "usage: $0 host user password" && exit 1
mysql_host=$1
mysql_user=$2
mysql_pass=$3
time for table in $(echo "SELECT concat(concat(table_schema,'.',table_name), '|', concat(round((data_length+index_length)/(1024*1024*1024),2),'G')) FROM information_schema.TABLES ORDER BY data_length+index_length DESC LIMIT 10" | mysql -N -r -u $mysql_user -h $mysql_host -p$mysql_pass)
do
        name=$(echo $table | cut -d '|' -f 1)
        size=$(echo $table | cut -d '|' -f 2)
        echo "Warming up table $name, Size: $size"
        echo "SELECT COUNT(*) FROM $name" | mysql -N -r -u $mysql_user -h $mysql_host -p$mysql_pass
done
exit 0
