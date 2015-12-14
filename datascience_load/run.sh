#!/bin/bash
#
#	selective parallel import of tables into a target DB
#	tables are imported in MyISAM to speed up things, partitions are coalesced if present, foreign keys dropped
#	tables go in Config file, one per line, in format server.schema.tablename or if InnoDB import desired - slow -
#		you should use server.schema.tablename.I
#
#	v2.0 14-Dec-2015
#	riccardo.pizzi@rumbo.com
#
export BASEDIR=/lm
export TARGET=8.8.8.8 # target server
export DUMPER=/usr/bin/mysqldump
export SOURCE_USER=
export SOURCE_PASS=
#
MAIL_RECIP="you@youremail.com"
#
tmpf=/tmp/dsload.$$
trap 'rm -f $tmpf' 0
IFS="
"
t_start=$(date +%s)
for row in $(cat $BASEDIR/etc/Config)
do
	source=$(echo $row | cut -d"." -f 1)
	schema=$(echo $row | cut -d"." -f 2)
	table=$(echo $row | cut -d"." -f 3)
	innodb=$(echo $row | cut -d"." -f 4)
	[ "$source" = "" -o "$schema" = "" -o "$table" = "" ] && continue
	$BASEDIR/bin/single.sh $schema $table $source $innodb 2>&1 &
done > $tmpf
wait
t_end=$(date +%s)
elapsed=$(expr $t_end  - $t_start)
echo "-------------------------------------------" >> $tmpf
min=$((elapsed/60))
secs=$((elapsed-min*60))
echo "Total running time $min minutes $secs seconds" >> $tmpf
cat $tmpf | tee $BASEDIR/log/last.log | mailx -s "Prod to QA import transcript" $MAIL_RECIP
exit 0
