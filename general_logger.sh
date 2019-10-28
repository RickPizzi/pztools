#!/bin/bash
#
# general logger - enable general log and handle daily files
# rick.pizzi@mariadb.com
# tweak folders below then run daily at midnight from cron
#
BASEDIR=/usr/local/mariadb/columnstore/mysql
BINDIR=$BASEDIR/bin
LOG_STORAGE=$BASEDIR/rdba
#
chown mysql:mysql $LOG_STORAGE
echo "set global general_log_file='$LOG_STORAGE/general.log'; set global general_log=ON;" | $BINDIR/mysql -A
logname=general_$(date +%Y-%m-%d -d "today - 1 day").log
mv $LOG_STORAGE/general.log $LOG_STORAGE/$logname 2>/dev/null
echo "flush general logs" | $BINDIR/mysql -A
gzip $LOG_STORAGE/$logname 2>/dev/null
exit 0
