#!/bin/bash
#
#	part of datascience load - should be called by load.sh
#	db user and password desumed from .my.cnf dot file
#	rpizzi@blackbirdit.com
#
#	Apr-10 fixes for partition check
#	Apr-10 create schema on DS if not there
#
schema=$1
table=$2
source=$3
rows=$(echo "SELECT table_rows FROM tables WHERE table_schema = '$schema' AND table_name ='${table}_NEW'" | mysql -N -r -h $DATASCIENCE information_schema)
if [ "$rows" != "" ]
then
	if [ $rows -gt 0 ]
	then   
		echo "[ $schema.$table ]  ERROR: found $schema.${table}_NEW with $rows rows in it, drop it to reload $table" 1>&2
		exit 1
	fi
fi
ts=$(date "+%m-%d-%Y %H:%M:%S ")
echo "$ts [ $schema.$table ]  importing "$schema"."$table" from $source"
partitions=$(echo "SELECT COUNT(*) FROM partitions WHERE table_schema = '$schema' AND table_name = '$table'" | mysql -N -r -h $source information_schema)
if [ $partitions -gt 1 ]
then
	filter="sed -e '/PARTITION/d' -e '/ENGINE/s/$/;/' -e 's/\`$table\`/\`${table}_NEW\`/g' -e 's/InnoDB/MyISAM/g'"
else
	filter="sed -e 's/\`$table\`/\`${table}_NEW\`/g' -e 's/InnoDB/MyISAM/g'"
fi
echo "CREATE DATABASE IF NOT EXISTS $schema" | mysql -h $DATASCIENCE
# make this a loop to trap mysqldump random failures
while true
do
	$DUMPER --single-transaction --skip-add-drop-table --no-create-info --max_allowed_packet=768M -h $source $schema $table | sed -e "s/\`$table\`/\`${table}_NEW\`/g" | (
		$DUMPER --no-data --skip-add-drop-table -h $source $schema $table | eval $filter
		echo "ALTER TABLE ${table}_NEW DISABLE KEYS;"
		cat
		echo "ALTER TABLE ${table}_NEW ENABLE KEYS;"
	) | mysql -A -h $DATASCIENCE $schema
	status=${PIPESTATUS[0]}
	if [ $status -eq 0 ]
	then
		break 
	else
		ts=$(date "+%m-%d-%Y %H:%M:%S ")
		echo "$ts [ $schema.$table ] WARNING: exited with error code $status, retrying"
		echo "DROP TABLE ${table}_NEW" | mysql -h $DATASCIENCE $schema
	fi
done
new_rows=$(echo "SELECT table_rows FROM tables WHERE table_schema = '$schema' AND table_name ='${table}_NEW'" | mysql -N -r -h $DATASCIENCE information_schema)
if [ $(echo "show tables" | mysql -A -N -r -h $DATASCIENCE $schema | grep -c "^"$table"$") -eq 1 ]
then
	old_rows=$(echo "SELECT table_rows FROM tables WHERE table_schema = '$schema' AND table_name ='${table}'" | mysql -N -r -h $DATASCIENCE information_schema)
	new_table=0
else
	old_rows=0  # table does not exist on data science
	new_table=1
fi
ts=$(date "+%m-%d-%Y %H:%M:%S ")
if [ "$new_rows" = "" -o "$old_rows" = "" ]
then
	echo "$ts [ $schema.$table ]  ERROR: loading of $schema.$table failed, original ${table} left untouched" 1>&2
	echo "DROP table ${table}_NEW" | mysql -h $DATASCIENCE $schema  # cleanup
	exit 1
fi
if [ $new_rows -lt $old_rows ]
then
	echo "$ts [ $schema.$table ]  WARNING: new table has less rows than old table, renaming it as ${table}_SAVED" 1>&2
	echo "DROP table IF EXISTS ${table}_SAVED" | mysql -h $DATASCIENCE $schema
	echo "RENAME TABLE $table TO ${table}_SAVED" | mysql -h $DATASCIENCE $schema
	echo "RENAME TABLE ${table}_NEW TO $table" | mysql -h $DATASCIENCE $schema
else
	if [ $new_table -eq 1 ]
	then
		echo "RENAME TABLE ${table}_NEW TO $table" | mysql -h $DATASCIENCE $schema
	else
		echo "RENAME TABLE $table TO ${table}_OLD, ${table}_NEW TO $table" | mysql -h $DATASCIENCE $schema
		echo "DROP table ${table}_OLD" | mysql -h $DATASCIENCE $schema
	fi
fi
echo "$ts [ $schema.$table ]  successfully loaded $new_rows rows into $schema.$table"
exit 0
