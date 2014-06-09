#!/bin/bash
#
# alter all tables in specified schemas, bumping the auto_increment value by $BUMP percent
# rpizzi@blackbirdit.com
#
SCHEMAS="schema1 schema2"
BUMP=0.25
#
schema_list=$(for s in $SCHEMAS; do echo "'"$s"'";done | tr "[\n]" "[,]" | sed -e "s/,$//g")
bump=$(echo "scale=3; ($BUMP + 100) / 100" | bc)
QUERY="select distinct c.table_schema, c.table_name from columns c left join key_column_usage k on c.table_schema = k.table_schema and c.table_name = k.table_name and c.column_name = k.column_name where c.TABLE_SCHEMA IN ($schema_list) and c.COLUMN_KEY <> '' and  c.DATA_TYPE IN ('bigint', 'int', 'mediumint', 'smallint', 'tinyint') and c.extra = 'auto_increment' and k.ordinal_position is not null group by c.table_schema, c.table_name, c.column_name"
IFS="
"
echo "-- altering all tables on $SCHEMAS"
echo "-- bumping autoincrement value by $BUMP%"
echo "--"
for row in $(echo "$QUERY" | mysql -N -r information_schema)
do
	schema=$(echo $row | cut -f 1)
	table=$(echo $row | cut -f 2)
	ai_val=$(echo "show create table $schema.$table\G" | mysql -A -N -r | fgrep "AUTO_INCREMENT=" | cut -d"=" -f 3 | cut -d" " -f 1)
	[ "$ai_val" = "" ] && ai_val=0
	new_val=$(echo "$ai_val * $bump + 1" | bc | cut -d"." -f 1)
	echo "-- on $schema.$table current value $ai_val"
	echo "ALTER TABLE $schema.$table AUTO_INCREMENT=$new_val;"
done
echo 1>&2
exit 0

