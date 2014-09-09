#!/bin/bash
#
#	takes an incremental based on last consolidated backup
#	and removes hourly incrementals afterwards
#	rpizzi@blackbirdit.com
#
DEFAULTS=/etc/default/backup_full
host=$(hostname | cut -d"." -f 1)

remote_server=$(grep "^remote_server=" $DEFAULTS | cut -d"=" -f 2)
remote_path=$(grep "^remote_path=" $DEFAULTS | cut -d"=" -f 2)
remote_user=$(grep "^remote_user=" $DEFAULTS | cut -d"=" -f 2)
local_path=$(grep "^local_path=" $DEFAULTS | cut -d"=" -f 2)
db_user=$(grep "^db_user=" $DEFAULTS | cut -d"=" -f 2)
db_pass=$(grep "^db_pass=" $DEFAULTS | cut -d"=" -f 2)
thread_count=$(grep "^parallelism=" $DEFAULTS | cut -d"=" -f 2)
xtrabackup=$(grep "^xtrabackup=" $DEFAULTS | cut -d"=" -f 2)

conf_file=/etc/my.cnf
socket=/var/lib/mysql/mysql.sock
lockfile=$local_path/cons_inprogress.lock
full_lockfile=$local_path/FS_inprogress.lock
incr_lockfile=$local_path/incr_inprogress.lock
local_err=/tmp/pdbfullbckerr.$$

backup_path=$local_path/incremental/
log_file=/var/log/backup_cons.log
lsn_dir=$local_path/lsn_cons

[ -f $lockfile ] && exit 1	# already in progress
[ -f $full_lockfile ] && exit 0	# full in progress, no consolidation today
while true
do
	[ ! -f $incr_lockfile ] && break 
	sleep 60 # incr running? wait
done

trap 'rm -f $lockfile $local_err' 0 
touch $lockfile

yesterpath=$(date -d "1 day ago" "+%Y/%m/%d")

file_time=$(date "+%Y%m%d_%H%M")
backup_file="consolidated.$file_time.xbs.gz"
date_path=$(date "+%Y/%m/%d")


ssh -q $remote_user@$remote_server "mkdir -p $remote_path/$date_path"
innobackupex --incremental --slave-info --no-lock --no-timestamp --parallel=$thread_count --ibbackup=/usr/bin/$xtrabackup  --socket=$socket --user=$db_user --password=$db_pass --defaults-file=$conf_file --stream=xbstream --extra-lsndir=$lsn_dir --incremental-basedir=$lsn_dir $backup_path 2>>$log_file | ssh -c arcfour128 -q $remote_user@$remote_server "gzip > $remote_path/$date_path/delta_$backup_file" 2>>$local_err
status=0
if [ -s $local_err ]
then
	echo "STREAMING ERROR DETECTED!"
	cat $local_err
	status=1
else
	cp $lsn_dir/xtrabackup_checkpoints $local_path/lsn_incr # next incr starts from this backup
	# remove hourly incremental(s) taken before the consolidation
	ssh -q $remote_user@$remote_server "rm -f $remote_path/$date_path/delta_inc*gz"
	# remove previous day's hourly incrementals
	ssh -q $remote_user@$remote_server "rm $remote_path/$yesterpath/delta_inc*gz"
fi >> $log_file
exit $status
