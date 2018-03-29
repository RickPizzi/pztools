#!/bin/bash
#
#	part of datascience load - should be called by load.sh
#	db user and password desumed from .my.cnf dot file
#	rpizzi@blackbirdit.com
#
#	10-Apr-2014 fixes for partition check
#	10-Apr-1014 create schema on TARGET if not there
#	14-Dec-2015 added innodb option 
#
schema=$1
table=$2
source=$3
[ "$4" = "I" ] && myisam="InnoDB" || myisam="MyISAM"
rows=$(echo "SELECT table_rows FROM tables WHERE table_schema = '$schema' AND table_name ='${table}_NEW'" | mysql -N -r -h $TARGET information_schema 2>/dev/null)
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
partitions=$(echo "SELECT COUNT(*) FROM partitions WHERE table_schema = '$schema' AND table_name = '$table'" | mysql -N -r -h $source -u$SOURCE_USER -p$SOURCE_PASS information_schema 2>/dev/null)
if [ $partitions -gt 1 ]
then
	filter="sed -e '/PARTITION/d' -e '/ENGINE/s/$/;/' -e 's/\`$table\`/\`${table}_NEW\`/g' -e 's/InnoDB/$myisam/g'"
else
	filter="sed -e 's/\`$table\`/\`${table}_NEW\`/g' -e 's/InnoDB/$myisam/g'"
fi
echo "CREATE DATABASE IF NOT EXISTS $schema" | mysql -h $TARGET 2>/dev/null
# make this a loop to trap mysqldump random failures
while true
do
	$DUMPER --skip-lock-tables --single-transaction --skip-add-drop-table --no-create-info --max_allowed_packet=768M -h $source -u$SOURCE_USER -p$SOURCE_PASS $schema $table 2>/dev/null | sed -e "s/\`$table\`/\`${table}_NEW\`/g" | (
		$DUMPER --skip-lock-tables --no-data --skip-add-drop-table -h $source -u$SOURCE_USER -p$SOURCE_PASS $schema $table 2>/dev/null | eval $filter
		echo "ALTER TABLE ${table}_NEW DISABLE KEYS;"
		echo "SELECT CONCAT('ALTER TABLE $schema'.${table}_NEW DROP FOREIGN KEY ',constraint_name,';') FROM information_schema.table_constraints WHERE constraint_type='FOREIGN KEY' AND table_schema='$schema';" | mysql -N -r -h $source -u$SOURCE_USER -p$SOURCE_PASS 2>/dev/null
		cat
		echo "ALTER TABLE ${table}_NEW ENABLE KEYS;"
	) | mysql -A -h $TARGET $schema 2>/dev/null
	status=${PIPESTATUS[0]}
	if [ $status -eq 0 ]
	then
		break 
	else
		ts=$(date "+%m-%d-%Y %H:%M:%S ")
		echo "$ts [ $schema.$table ] WARNING: exited with error code $status, retrying"
		echo "DROP TABLE ${table}_NEW" | mysql -h $TARGET $schema 2>/dev/null
	fi
done
new_rows=$(echo "SELECT table_rows FROM tables WHERE table_schema = '$schema' AND table_name ='${table}_NEW'" | mysql -N -r -h $TARGET information_schema 2>/dev/null)
if [ $(echo "show tables" | mysql -A -N -r -h $TARGET $schema 2>/dev/null | grep -c "^"$table"$") -eq 1 ]
then
	old_rows=$(echo "SELECT table_rows FROM tables WHERE table_schema = '$schema' AND table_name ='${table}'" | mysql -N -r -h $TARGET information_schema 2>/dev/null)
	new_table=0
else
	old_rows=0  # table does not exist on target
	new_table=1
fi
ts=$(date "+%m-%d-%Y %H:%M:%S ")
if [ "$new_rows" = "" -o "$old_rows" = "" ]
then
	echo "$ts [ $schema.$table ]  ERROR: loading of $schema.$table failed, original ${table} left untouched" 1>&2
	echo "DROP table ${table}_NEW" | mysql -h $TARGET $schema 2>/dev/null # cleanup
	exit 1
fi
if [ $new_rows -lt $old_rows ]
then
	echo "$ts [ $schema.$table ]  WARNING: new table has less rows than old table, renaming it as ${table}_SAVED" 1>&2
	echo "DROP table IF EXISTS ${table}_SAVED" | mysql -h $TARGET $schema 2>/dev/null
	echo "RENAME TABLE $table TO ${table}_SAVED" | mysql -h $TARGET $schema 2>/dev/null
	echo "RENAME TABLE ${table}_NEW TO $table" | mysql -h $TARGET $schema 2>/dev/null
else
	if [ $new_table -eq 1 ]
	then
		echo "RENAME TABLE ${table}_NEW TO $table" | mysql -h $TARGET $schema 2>/dev/null
	else
		echo "RENAME TABLE $table TO ${table}_OLD, ${table}_NEW TO $table" | mysql -h $TARGET $schema 2>/dev/null
		echo "DROP table ${table}_OLD" | mysql -h $TARGET $schema 2>/dev/null
	fi
fi
echo "$ts [ $schema.$table ]  successfully loaded $new_rows rows into $schema.$table"
exit 0
