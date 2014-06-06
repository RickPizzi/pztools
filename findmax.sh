#!/bin/bash
#
# rpizzi@palominodb.com
#
QUERY="select distinct c.table_schema, c.table_name, c.column_name, c.data_type, if (c.column_type LIKE '%unsigned', 'unsigned', '') as uns, if (c.extra = 'auto_increment', 'autoinc', '') as autoinc, min(k.ordinal_position) from columns c left join key_column_usage k on c.table_schema = k.table_schema and c.table_name = k.table_name and c.column_name = k.column_name where c.TABLE_SCHEMA NOT IN ('information_schema','mysql') and c.COLUMN_KEY <> '' and  c.DATA_TYPE IN ('bigint', 'int', 'mediumint', 'smallint', 'tinyint') and k.ordinal_position is not null group by c.table_schema, c.table_name, c.column_name"
#QUERY="select distinct c.column_name, c.table_schema, c.table_name, c.data_type, if (c.column_type LIKE '%unsigned', 'unsigned', '') as uns, if (c.extra = 'auto_increment', 'autoinc', '') as autoinc, k.ordinal_position from columns c left join key_column_usage k on c.table_schema = k.table_schema and c.table_name = k.table_name and c.column_name = k.column_name where c.TABLE_SCHEMA NOT IN ('information_schema','mysql') and c.COLUMN_KEY <> '' and  c.DATA_TYPE IN ('bigint', 'int', 'mediumint', 'smallint', 'tinyint') and k.ordinal_position is not null"
#QUERY="select c.column_name, c.table_schema, c.table_name, c.data_type, if (c.column_type LIKE '%unsigned', 'unsigned', '') as uns, if (c.extra = 'auto_increment', 'autoinc', '') as autoinc, c.column_type from columns c left join key_column_usage k on c.table_schema = k.table_schema and c.table_name = k.table_name and c.column_name = k.column_name where c.TABLE_SCHEMA NOT IN ('information_schema','mysql') and c.COLUMN_KEY <> '' and  c.DATA_TYPE IN ('bigint', 'int', 'mediumint', 'smallint', 'tinyint') and k.ordinal_position = 1"
#
[ "$1" = "" ] && echo "usage: $0 dbhost" && exit 1
IFS="
"
echo "SCHEMA NAME,TABLE NAME,COLUMN NAME,COLUMN TYPE,UNSIGNED?,AUTOINC?,MAX VALUE,COLUMN LIMIT,%FULL"
for row in $(echo "$QUERY" | mysql -h $1 -N -r information_schema)
do
	schema=$(echo $row | cut -f 1)
	table=$(echo $row | cut -f 2)
	col=$(echo $row | cut -f 3)
	type=$(echo $row | cut -f 4)
	unsigned=$(echo $row | cut -f 5)
	autoinc=$(echo $row | cut -f 6)
	keypos=$(echo $row | cut -f 7)
	if [ $keypos -ne 1 ]
	then
		# not listed in information_schema.key_column_usage as leftmost part of a key
		# still, it could be indexed. let's see... 
		echo "show create table $schema.$table" | mysql -h $1 -A -N -r  | grep "^  KEY" | fgrep -q "(\`$col\`)"
		if [ $? -ne 0 ]
		then
			echo 1>&2
			echo "Warning: not checking $schema.$table.$col because it would be a table scan, but it should be checked" 1>&2
			continue
		fi
	fi
	case "$type" in
		'tinyint') [ $unsigned ] && limit=255 || limit=127;;
		'smallint') [ $unsigned ] && limit=65535 || limit=32767;;
		'mediumint') [ $unsigned ] && limit=16777215 || limit=8388607;;
		'int') [ $unsigned ] && limit=4294967295 || limit=2147483647;;
		'bigint') [ $unsigned ] && limit=18446744073709551615 || limit=9223372036854775807;;
		*) echo "error $type"; exit 1;;
	esac
	echo -n "." 1>&2
	max=$(echo "select max(\`$col\`) from $schema.$table" | mysql -h $1 -A -N -r)
	[ "$max" = "NULL" ] && max=0 # empty table
	perc=$(echo "scale=2;$max * 100 / $limit" | bc)
	echo $schema","$table","$col","$type","$unsigned","$autoinc","$max","$limit","$perc
done
echo 1>&2
exit 0
