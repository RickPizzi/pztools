#!/bin/bash
#
#	selective parallel import of tables into data science DB
#	tables are imported in MyISAM to speed up things, partitions are coalesced if present
#	tables go in Config file, one per line, in format schema.tablename
#	each schema you want to import should be listed in the "case" statement below with the IP address 
#				of the MySQL server where it resides
#	rpizzi@blackbirdit.com
#
export BASEDIR=/root/Datascience_load
export DATASCIENCE=10.57.25.52 # target server
export DUMPER=$BASEDIR/mysqldump55_patched
#
MAIL_RECIP="rpizzi@blackbirdit.com"
#
tmpf=/tmp/dsload.$$
trap 'rm -f $tmpf' 0
IFS="
"
t_start=$(date +%s)
for row in $(cat $BASEDIR/Config)
do
	schema=$(echo $row | cut -d"." -f 1)
	table=$(echo $row | cut -d"." -f 2)
	source=""
	case "$schema" in
		'comments') source="10.57.14.49";;
		'files'|'internal') source="10.57.14.21";;
		'snapshot') source="10.57.14.14";;
		*) echo "[ $schema.$table ]  schema '$schema' not known, ignoring" 1>&2 ;;
	esac
	[ "$source" = "" ] && continue
	$BASEDIR/import_single_table.sh $schema $table $source 2>&1 &
done > $tmpf
wait
t_end=$(date +%s)
elapsed=$(expr $t_end  - $t_start)
echo "-------------------------------------------" >> $tmpf
echo "Total running time $(expr $elapsed / 60) minutes" >> $tmpf
cat $tmpf | tee $BASEDIR/last.log | mailx -s "Data Science import transcript" $MAIL_RECIP
exit 0
