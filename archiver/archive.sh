#!/bin/bash
#
#	main archiver script - v. 1.03
#	assumes:
#	- table is partitioned by range
#	- (leftmost part of) primary key is an auto_increment integer
#	requires:
#	- latest version of percona toolkit (pt-archiver >= 3.0.4)
#	- partition boundary is monday if weekly
#
SOURCE=localhost	# source MySQL server
USER=mariadbadmin	# user on source server
PASS=			# MySQL password for such user, leave blank to use dot file
DEST=			# destination MySQL server; if empty, target must be archiving path
RETENTION=15		# retention as defined in partition management scripts, MUST match
RETENTION_UNIT="week"	# retention unit: week, month, year
#
if [ $# -lt 5 ]
then
	echo "usage: $0 <schema> <table> <pk> <part. key> <target> <extra>"
	exit 1
fi
KEY=$3
EXTRA=$6
if [ "$DEST" = "" ]
then
	if [ ! -d $5 ]
	then
		echo "$5 is not a valid folder"
		exit 1
	fi
	[ ! -d $5/$(date +%Y) ] && mkdir $5/$(date +%Y)
else
	TARGET=$5
fi
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
	*)  	echo "$1.$2: doesn't look like a partitioned table!"; exit 1;;
esac
ref_date=$(date "+%Y-%m-%d")
if [ "$RETENTION_UNIT" = "week" ]
then
	# make sure we archive based on monday
	if [ $(date +%w) -ne 1 ]
	then
  		ref_date=$(date -d "last monday" "+%Y-%m-%d")
	fi
fi
last_partition_name=$(echo "SELECT PARTITION_NAME  FROM information_schema.PARTITIONS where PARTITION_NAME is not null AND TABLE_NAME = '$2' and TABLE_SCHEMA='$1' AND TABLE_ROWS > 0 AND PARTITION_DESCRIPTION < $partition_key_type('$ref_date' - interval $RETENTION $RETENTION_UNIT)" | mysql -ANr -u$USER $password -h $SOURCE 2>/dev/null| tail -1)
if [ "$last_partition_name" = "" ]
then
	echo "$1.$2: no partition to archive."
	exit 0
fi
echo "$1.$2: archive up to partition: $last_partition_name"
if [ "$EXTRA" = "" ]
then
	last_key_to_archive=$(echo "select MAX($KEY) from $2 partition($last_partition_name)" | mysql -ANr -u$USER $password -h $SOURCE $1 2>/dev/null)
else
	last_key_to_archive=$(echo "select $KEY from $2 partition($last_partition_name) where $EXTRA order by 1 desc limit 1" | mysql -ANr -u$USER $password -h $SOURCE $1 2>/dev/null)
fi
echo "$1.$2: last $KEY value in $last_partition_name: $last_key_to_archive"
if [ "$DEST" != "" ]
then
	last_archive_key=$(echo "select MAX($KEY) from $TARGET" | mysql -ANr -u$USER -p$PASS -h $DEST $1 2>/dev/null)
else
        last_archive_key=$(tail -1 $5/$SOURCE/$1/$2/*_$last_partition_name.sql  2>/dev/null | cut -d"(" -f 2 | cut -d"," -f 1)
	[ "$last_archive_key" = "" ] && last_archive_key=0
fi
echo "$1.$2: last $KEY value in archive: $last_archive_key"
if [ "$last_archive_key" = "$last_key_to_archive" ]
then
	echo "$1.$2: already archived, nothing to do."
	exit 0
fi
if [ $last_archive_key -gt $last_key_to_archive ]
then
	echo "$1.$2: something is wrong, archive has higher $KEY value than source!"
	exit 1
fi
source_charset=$(echo "SHOW CREATE TABLE $1.$2" | mysql -ANr -u$USER $password -h $SOURCE | fgrep "DEFAULT CHARSET" | cut -d"=" -f 4 | cut -d " " -f 1 2>/dev/null)
[ "$PASS" != "" ] && pt_password="p=$PASS,"
echo "$1.$2: archiving started"
if [ "$DEST" = "" ]
then
	[ ! -d $5/$SOURCE/$1/$2 ] && mkdir -p $5/$SOURCE/$1/$2
	if [ "$EXTRA" = "" ]
	then
		echo "$1.$2: executing: mysqldump --single-transaction --skip-extended-insert --compact  -u$USER -p***** --where=\"$KEY <= $last_key_to_archive\" $1 $2 "
		time mysqldump --single-transaction --skip-extended-insert --compact  -u$USER $password --where="$KEY <= $last_key_to_archive" $1 $2 > $5/$SOURCE/$1/$2/$(date +%Y%m%d)_$last_partition_name.sql
	else
		# need fixed pt-archiver --no-version-check --no-delete --limit 10000 --txn-size 10000 --statistics --source h=$SOURCE,u=$USER,${pt_password}D=$1,t=$2,A=$source_charset --file $arcfile --where "$KEY <= $last_key_to_archive AND $EXTRA"
	fi
else
	if [ "$EXTRA" = "" ]
	then
		# need fixed pt-archiver --no-version-check --no-delete --limit 10000 --txn-size 10000 --statistics --source h=$SOURCE,u=$USER,${pt_password}D=$1,t=$2,A=$source_charset --dest h=$DEST,t=$TARGET,u=$USER,p=$PASS,S=/db/data/mysql.sock --where "$KEY <= $last_key_to_archive"
	else
		# need fixed 	pt-archiver --no-version-check --no-delete --limit 10000 --txn-size 10000 --statistics --source h=$SOURCE,u=$USER,${pt_password}D=$1,t=$2,A=$source_charset --dest h=$DEST,t=$TARGET,u=$USER,p=$PASS,S=/db/data/mysql.sock --where "$KEY <= $last_key_to_archive AND $EXTRA"
	fi
fi
status=$?
echo "$1.$2: archiving completed with status $status."
exit $status

