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
base=$(basename $(grep ^log_bin /etc/my.cnf | cut -d"=" -f 2))
min_pos=1000000
echo "Starting $(date)"
for slave in $(echo "select substring_index(host, ':', 1)  from information_schema.processlist where command = 'binlog dump'" | mysql -ANr -h $MASTER_HOST -u $REPL_USER -p$REPL_PASSWORD 2>/dev/null)
do
	if [ -s /tmp/slave_$slave.pos ]	# check if there is an uploaded position first
	then
		sp=$(cat /tmp/slave_$slave.pos)
	else
		sp=$(echo "show slave status\G" | mysql -Ar -h $slave -u $REPL_USER -p$REPL_PASSWORD 2>/dev/null | fgrep Relay_Master_Log_File | cut -d ":" -f 2)
	fi
	echo "* slave $slave has binlog $sp"
	[ ${sp#*.} -lt $min_pos ] && min_pos=${sp#*.}
done
echo "* all slaves low water mark: $min_pos"
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
