#
#	gracefully rotates slow query log
#	rpizzi@blackbirdit.com
#
SLOWDIR=/var/log/mysql
SLOWFILE=mysqld_slow.log
RETENTION=7
#
USER=reload
PASS="...."
HOST=localhost
#
c=$RETENTION
mv $SLOWDIR/$SLOWFILE $SLOWDIR/$SLOWFILE.1
echo "FLUSH LOGS" | mysql -u $USER -h $HOST -p$PASS
while true
do
	[ $c -eq 0 ] && break
	if [ $c -eq $RETENTION ]
	then
		[ -f $SLOWDIR/$SLOWFILE.${c}.gz ] && rm -f $SLOWDIR/$SLOWFILE.$c.gz
	else
		older=$(expr $c + 1)
		[ -f $SLOWDIR/$SLOWFILE.${c}.gz ] && mv $SLOWDIR/$SLOWFILE.${c}.gz $SLOWDIR/$SLOWFILE.${older}.gz
	fi
	c=$(expr $c - 1)
done
gzip $SLOWDIR/$SLOWFILE.1
exit 0
