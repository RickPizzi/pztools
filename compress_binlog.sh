#!/bin/bash
#
#	automatic compression of MySQL binlog files
#	riccardo.pizzi@lastminute.com
#
#
BINLOG_DIR=/storage/binlog
COMPRESSOR=pigz
COMPRESS_OPTIONS="-p 4"
COMPRESS_EXTENSION=gz
MIN_AGE_FOR_COMPRESSION=60
REPL_USER=
REPL_PASSWORD=
MASTER_HOST=localhost
#
tmpf=/tmp/compress_binlog.lock
echo "Starting $(date)"
if [ -f $tmpf ]
then
	echo "Already in progress, exiting"
	exit 0
fi
trap 'rm -f $tmpf' 0
touch $tmpf
base=$(basename $(grep ^log_bin /etc/my.cnf | cut -d"=" -f 2))
min_pos=1000000
sc=0
for slave in $(echo "select substring_index(host, ':', 1)  from information_schema.processlist where command = 'binlog dump'" | mysql -ANr -h $MASTER_HOST -u $REPL_USER -p$REPL_PASSWORD 2>/dev/null)
do
	if [ -s /tmp/slave_$slave.pos ]	# check if there is an uploaded position first
	then
		sp=$(cat /tmp/slave_$slave.pos)
	else
		sp=$(echo "show slave status\G" | mysql -Ar -h $slave -u $REPL_USER -p$REPL_PASSWORD 2>/dev/null | fgrep " Master_Log_File" | cut -d ":" -f 2)
	fi
	if [ "$sp" != "" ]
	then
		echo "* slave $slave last downloaded binlog $sp"
		[ ${sp#*.} -lt $min_pos ] && min_pos=${sp#*.}
		sc=$((sc+1))
	fi
done
if [ $sc -eq 0 ]
then
	echo "* no slaves detected"
else
	echo "* last downloaded file of most lagging slave: $min_pos"
fi
cd $BINLOG_DIR
for f in $(find $BINLOG_DIR -name $base.[0-9]\* -mmin +$MIN_AGE_FOR_COMPRESSION | sort)
do
	[ ${f#*.} -ge $min_pos ] && break
	if [[ $(file -b $f) == "MySQL"* ]]
	then
		echo "> compressing $(basename $f)"
		$COMPRESSOR $COMPRESS_OPTIONS $f
		mv $f.$COMPRESS_EXTENSION $f
	fi
done
echo "Completed $(date)"
