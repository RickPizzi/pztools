#!/bin/bash
#
#	main archiver script - v. 1.01
#	assumes:
#	- table is partitioned by range
#	- (leftmost part of) primary key is an auto_increment integer
#	requires:
#	- latest version of percona toolkit (pt-archiver >= 3.0.4)
#
SOURCE=dbstat01	# source MySQL server
DEST=dbstat01	# destination MySQL server
USER=archiver	# MySQL user for archiviation (requires SELECT on source tables, INSERT on dest tables)
PASS=secret	# MySQL password for such user
RETENTION=12	# retention as defined in partition management scripts, MUST match
#
if [ $# -lt 5 ]
then
	echo "usage: $0 <schema> <table> <pk> <part. key> <target> <extra>"
	exit 1
fi
KEY=$3
TARGET=$5
EXTRA=$6
partition_key_type=$(echo "SHOW CREATE TABLE $1.$2" | mysql -ANr -u$USER -p$PASS -h $SOURCE 2>/dev/null| fgrep "PARTITION BY RANGE" | cut -d"(" -f 2)
case "$partition_key_type" in
	'UNIX_TIMESTAMP') partition_filter="FROM_UNIXTIME";;
	'TO_DAYS') partition_filter="FROM_DAYS";;
	*) echo "$1.$2: doesn't look like a partitioned table!"; exit 1;;
esac
last_partition_name=$(echo "SELECT PARTITION_NAME  FROM information_schema.PARTITIONS where PARTITION_NAME is not null AND TABLE_NAME = '$2' and TABLE_SCHEMA='$1' AND TABLE_ROWS > 0 AND PARTITION_DESCRIPTION < $partition_key_type(current_date - interval $RETENTION MONTH)" | mysql -ANr -u$USER -p$PASS -h $SOURCE 2>/dev/null| tail -1)
if [ "$last_partition_name" = "" ]
then
	echo "No partition to archive for $1.$2"
	exit 0
fi
echo "Last partition to archive: $last_partition_name"
if [ "$EXTRA" = "" ]
then
	last_key_to_archive=$(echo "select MAX($KEY) from $2 partition($last_partition_name)" | mysql -ANr -u$USER -p$PASS -h $SOURCE $1 2>/dev/null)
else
	last_key_to_archive=$(echo "select $KEY from $2 partition($last_partition_name) where $EXTRA order by 1 desc limit 1" | mysql -ANr -u$USER -p$PASS -h $SOURCE $1 2>/dev/null)
fi
echo "Last $KEY value in $last_partition_name: $last_key_to_archive"
last_archive_key=$(echo "select MAX($KEY) from $TARGET" | mysql -ANr -u$USER -p$PASS -h $DEST $1 2>/dev/null)
echo "Last $KEY value in archive: $last_archive_key"
if [ "$last_archive_key" = "$last_key_to_archive" ]
then
	echo "Nothing to do."
	exit 0
fi
if [ $last_archive_key -gt $last_key_to_archive ]
then
	echo "Something is wrong, archive has higher $KEY value than source!"
	exit 1
fi
partition_limit=$(echo "SELECT MAX(PARTITION_DESCRIPTION)  FROM information_schema.PARTITIONS where PARTITION_NAME is not null AND TABLE_NAME = '$2' and TABLE_SCHEMA='$1' AND TABLE_ROWS > 0 AND PARTITION_DESCRIPTION < $partition_key_type(current_date - interval $RETENTION MONTH)" | mysql -ANr -u$USER -p$PASS -h $SOURCE  2>/dev/null| tr "\n" "," | sed -e "s/,$//")
source_charset=$(echo "SHOW CREATE TABLE $1.$2" | mysql -ANr -u$USER -p$PASS -h $SOURCE | fgrep "DEFAULT CHARSET" | cut -d"=" -f 4 | cut -d " " -f 1 2>/dev/null)
if [ "$EXTRA" = "" ]
then
	pt-archiver --no-version-check --no-delete --limit 10000 --txn-size 10000 --statistics --source h=$SOURCE,u=$USER,p=$PASS,D=$1,t=$2,A=$source_charset --dest h=$DEST,t=$TARGET,u=$USER,p=$PASS,S=/db/data/mysql.sock --where "$4 < $partition_filter($partition_limit)"
else
	pt-archiver --no-version-check --no-delete --limit 10000 --txn-size 10000 --statistics --source h=$SOURCE,u=$USER,p=$PASS,D=$1,t=$2,A=$source_charset --dest h=$DEST,t=$TARGET,u=$USER,p=$PASS,S=/db/data/mysql.sock --where "$4 < $partition_filter($partition_limit) AND $EXTRA"
fi
exit 0
