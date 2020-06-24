#!/bin/bash
#
#	checks whether retention needs (and can) applied to a partitioned table
#	you can use the exit status to run the table dropping script, e.g. pdb-parted, see examples
#
SOURCE=localhost	# source MySQL server
USER=mariadbadmin   	# MySQL user for archiviation (requires SELECT on source tables, INSERT on dest tables)
PASS=		     	# MySQL password for such user
DEST=		   	# destination MySQL server, or mount point for archive files
RETENTION=16    	# retention as defined in partition management scripts, MUST match
RETENTION_UNIT="week"  	# retention unit: week, month, year
#
if [ $# -lt 4 ]
then
	echo "usage: $0 <schema> <table> <pk> <target> <extra>"
	exit 1
fi
KEY=$3
TARGET=$4
EXTRA=$5
[ "$PASS" != "" ] && password="-p $PASS"
partition_function=$(echo "SHOW CREATE TABLE $1.$2" | mysql -ANr -u$USER $password -h $SOURCE 2>/dev/null| fgrep "PARTITION BY RANGE" | tr -d '`')
if [ $(echo "$partition_function" | fgrep -c " DIV ") -eq 1 ]
then
        partition_key_type="UNIX_TIMESTAMP"
        div=$(echo "$partition_function" | sed -re "s/(.*)Fecha(.*)\)/\2/")
else
        partition_key_type=$(echo "$partition_function" | cut -d"(" -f 2)
fi
case "${partition_key_type^^}" in
        'UNIX_TIMESTAMP') partition_filter="FROM_UNIXTIME";;
        'TO_DAYS') partition_filter="FROM_DAYS";;
        *)      echo "$1.$2: doesn't look like a partitioned table!"; exit 1;;
esac
last_partition_name=$(echo "SELECT PARTITION_NAME  FROM information_schema.PARTITIONS where PARTITION_NAME is not null AND TABLE_NAME = '$2' and TABLE_SCHEMA='$1' AND TABLE_ROWS > 0 AND PARTITION_DESCRIPTION <= $partition_key_type(current_date - interval $RETENTION $RETENTION_UNIT)" | mysql -ANr -u$USER $password -h $SOURCE 2>/dev/null | tail -1)
if [ "$last_partition_name" = "" ]
then
	echo "$1.$2: nothing to do, exiting"
	exit 1
fi
echo "$1.$2: checking status of last partition that should be in archive, $last_partition_name ..."
if [ "$EXTRA" = "" ]
then
	last_key_to_archive=$(echo "select MAX($KEY) from $2 partition($last_partition_name)" | mysql -ANr -u$USER $password -h $SOURCE $1 2>/dev/null)
else
	last_key_to_archive=$(echo "select $KEY from $2 partition($last_partition_name) where $EXTRA order by 1 desc limit 1" | mysql -ANr -u$USER $password -h $SOURCE $1 2>/dev/null)
fi
[ "$last_key_to_archive" = "" ] && exit 1
echo "$1.$2: Last $KEY value in $last_partition_name: $last_key_to_archive"
if [ "$DEST" = "" ]
then
	last_archive_key=$(tail -1 $4/$SOURCE/$1/$2/*_$last_partition_name.sql 2>/dev/null | cut -d"(" -f 2 | cut -d"," -f 1)
	[ "$last_archive_key" = "" ] && last_archive_key="not found"
	echo "$1.$2: Last $KEY value from $4/$SOURCE/$1/$2/*_$last_partition_name.sql: $last_archive_key"
else
	last_archive_key=$(echo "select MAX($KEY) from $TARGET" | mysql -ANr -u$USER $password -h $DEST $1 2>/dev/null)
	echo "$1.$2: Last $KEY value for table $TARGET in archive: $last_archive_key"
fi
if [ "$last_archive_key" = "$last_key_to_archive" ]
then
	echo "$1.$2: partition $last_partition_name was successfully archived, OK to drop"
	exit 0
else
	echo "$1.$2: partition $last_partition_name was not archived properly, NOT OK to proceed"
	exit 1
fi
