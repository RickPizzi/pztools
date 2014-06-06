#!/bin/bash
#
#	full backup script
#	rpizzi@blackbirdit.com
#
DEFAULTS=/etc/default/backup_full
remote_server=$(grep "^remote_server=" $DEFAULTS | cut -d"=" -f 2)
remote_path=$(grep "^remote_path=" $DEFAULTS | cut -d"=" -f 2)
remote_user=$(grep "^remote_user=" $DEFAULTS | cut -d"=" -f 2)
local_path=$(grep "^local_path=" $DEFAULTS | cut -d"=" -f 2)
db_user=$(grep "^db_user=" $DEFAULTS | cut -d"=" -f 2)
db_pass=$(grep "^db_pass=" $DEFAULTS | cut -d"=" -f 2)
thread_count=$(grep "^parallelism=" $DEFAULTS | cut -d"=" -f 2)
xtrabackup=$(grep "^xtrabackup=" $DEFAULTS | cut -d"=" -f 2)
purge_user=$(grep "^purge_user=" $DEFAULTS | cut -d"=" -f 2)
purge_pass=$(grep "^purge_pass=" $DEFAULTS | cut -d"=" -f 2)

conf_file=/etc/my.cnf
socket=/var/lib/mysql/mysql.sock
lockfile=$local_path/FS_inprogress.lock
inc_lockfile=$local_path/inc_inprogress.lock
local_err=/tmp/pdbfullbckerr.$$

backup_path=$local_path/full/
log_file=/var/log/backup_full.log
lsn_dir=$local_path/lsn_incr
lsn_dir_cons=$local_path/lsn_cons


[ -f $lockfile ] && exit 1	# already in progress
while [ -f $inc_lockfile ] 
do
	sleep 600		# wait for incremental to complete
done
trap 'rm -f $lockfile $local_err' 0 
touch $lockfile

# get last LSN to purge tracking files later
last_lsn=$(fgrep -h last_lsn /backup/lsn*/xtrabackup_checkpoints | tr -d "[ ]" | cut -d"=" -f 2 | sort -n | tail -1)
echo $last_lsn > /backup/full/last_lsn

file_time=$(date "+%Y%m%d_%H%M")
backup_file="$file_time.xbs.gz"
date_path=$(date "+%Y/%m/%d")
[ ! -d $lsn_path ] && mkdir $lsn_path
[ ! -d $lsn_dir_cons ] && mkdir -p $lsn_dir_cons

ssh -q $remote_user@$remote_server "mkdir -p $remote_path/$date_path"
innobackupex --no-version-check --parallel=$thread_count --slave-info --ibbackup=/usr/bin/$xtrabackup  --socket=$socket --user=$db_user --password=$db_pass --tmpdir=$local_path/tmp --defaults-file=$conf_file --stream=xbstream --extra-lsndir=$lsn_dir $backup_path 2>>$log_file | ssh -c arcfour128 -q $remote_user@$remote_server "gzip > $remote_path/$date_path/FS_$backup_file" 2>>$local_err

status=0
if [ -s $local_err ]
then
	echo "STREAMING ERROR DETECTED!"
	cat $local_err
	status=1
else
        cp $lsn_dir/xtrabackup_checkpoints $lsn_dir_cons # starting point for consolidated backups
	echo "PURGE CHANGED_PAGE_BITMAPS BEFORE $(expr $last_lsn + 1)" | mysql -u $purge_user -h localhost -p$purge_pass
fi >> $log_file
exit $status
