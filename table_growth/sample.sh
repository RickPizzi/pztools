#!/bin/bash
#
#	populates table growth DB from selected slaves
#	rick.pizzi@mariadb.com
#
SKIP_SCHEMAS="information_schema performance_schema mysql"
DB_SCHEMA=growth
SKIP_TABLES="$DB_SCHEMA.growth"
DB_USER=tablegrowth
DB_PASS=yourpasshere
DATADIR=/var/lib/mysql
#
c=0
for ss in $SKIP_SCHEMAS
do
	[ $c -gt 0 ] && sskip="$sskip|"
	sskip="$sskip^$ss/"
	c=$((c+1))
done
c=0
for ss in $(echo $SKIP_TABLES | tr "[.]" "[/]") 
do
	[ $c -gt 0 ] && tskip="$tskip|"
	tskip="$tskip^$ss"
	c=$((c+1))
done
cd $DATADIR
IFS="
"
for ts in $(find . -type f -name \*ibd | cut -d "/" -f 2,3 | egrep -v "$sskip" | egrep -v "$tskip" | cut -d "." -f 1)
do
	echo "insert into growth values (null, curdate(), @@hostname, $(echo $ts| sed -re "s/(.*)\/(.*)/'\1', '\2'/g"), $(($(stat -c %s ./$ts.ibd)/1024/1024)));" 
done | mysql -A $DB_SCHEMA
exit 0
