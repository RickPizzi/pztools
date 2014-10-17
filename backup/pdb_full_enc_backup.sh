#!/bin/ksh
#
#       full backup with parallel encryption
#       rpizzi@blackbirdit.com
#
ulimit -n 8192
CHUNK=2048 # blocks
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
enc_key=$(grep "^enc_key=" $DEFAULTS | cut -d"=" -f 2)

ENC_CMD="openssl enc -aes-256-cbc -pass file:$enc_key"

conf_file=/etc/my.cnf
socket=/var/lib/mysql/mysql.sock
lockfile=$local_path/FS_inprogress.lock
inc_lockfile=$local_path/inc_inprogress.lock
local_err=/tmp/pdbfullbckerr.$$
key=/root/.ssh/mysql_backup


backup_path=$local_path/full/
log_file=/var/log/mysql_full_backup.log
lsn_dir=$local_path/lsn_incr

[ -f $lockfile ] && exit 1      # already in progress
while [ -f $inc_lockfile ]
do
        sleep 600               # wait for incremental to complete
done
trap 'rm -f $lockfile $local_err' 0
touch $lockfile

# get last LSN to purge tracking file later
last_lsn=$(fgrep -h last_lsn /backup/lsn_*/xtrabackup_checkpoints | tr -d "[ ]" | cut -d"=" -f 2 | sort -n | tail -1)

file_time=$(date "+%Y%m%d_%H%M")
backup_file="$file_time.xbs.gz"
date_path=$(date "+%Y/%m/%d")
[ ! -d $lsn_path ] && mkdir $lsn_path

ssh -q -i $key $remote_user@$remote_server "mkdir -p $remote_path/$date_path"

# encryption slots setup
$ENC_CMD | ssh -q  -i $key $remote_user@$remote_server "cat > $remote_path/$date_path/FS_${backup_file}_piece0" |&
exec {s0}>&p
$ENC_CMD | ssh -q  -i $key $remote_user@$remote_server "cat > $remote_path/$date_path/FS_${backup_file}_piece1" |&
exec {s1}>&p
$ENC_CMD | ssh -q  -i $key $remote_user@$remote_server "cat > $remote_path/$date_path/FS_${backup_file}_piece2" |&
exec {s2}>&p
$ENC_CMD | ssh -q  -i $key $remote_user@$remote_server "cat > $remote_path/$date_path/FS_${backup_file}_piece3" |&
exec {s3}>&p
$ENC_CMD | ssh -q  -i $key $remote_user@$remote_server "cat > $remote_path/$date_path/FS_${backup_file}_piece4" |&
exec {s4}>&p
#$ENC_CMD | ssh -q  -i $key $remote_user@$remote_server "cat > $remote_path/$date_path/FS_${backup_file}_piece5" |&
#exec {s5}>&p
#$ENC_CMD | ssh -q  -i $key $remote_user@$remote_server "cat > $remote_path/$date_path/FS_${backup_file}_piece6" |&
#exec {s6}>&p
#$ENC_CMD | ssh -q  -i $key $remote_user@$remote_server "cat > $remote_path/$date_path/FS_${backup_file}_piece7" |&
#exec {s7}>&p
#$ENC_CMD | ssh -q  -i $key $remote_user@$remote_server "cat > $remote_path/$date_path/FS_${backup_file}_piece8" |&
#exec {s8}>&p
#$ENC_CMD | ssh -q  -i $key $remote_user@$remote_server "cat > $remote_path/$date_path/FS_${backup_file}_piece9" |&
#exec {s9}>&p

innobackupex --no-version-check --parallel=$thread_count --slave-info --ibbackup=/usr/bin/$xtrabackup  --socket=$socket --user=$db_user --password=$db_pass --tmpdir=/mnt/storage1/tmp --defaults-file=$conf_file --stream=xbstream --extra-lsndir=$lsn_dir $backup_path 2>>$log_file | pigz | while true
do
	[[ $(dd count=$CHUNK 2>&1 >&$s0) == *0+0* ]] && break
	[[ $(dd count=$CHUNK 2>&1 >&$s1) == *0+0* ]] && break
	[[ $(dd count=$CHUNK 2>&1 >&$s2) == *0+0* ]] && break
	[[ $(dd count=$CHUNK 2>&1 >&$s3) == *0+0* ]] && break
	[[ $(dd count=$CHUNK 2>&1 >&$s4) == *0+0* ]] && break
#	[[ $(dd count=$CHUNK 2>&1 >&$s5) == *0+0* ]] && break
#	[[ $(dd count=$CHUNK 2>&1 >&$s6) == *0+0* ]] && break
#	[[ $(dd count=$CHUNK 2>&1 >&$s7) == *0+0* ]] && break
#	[[ $(dd count=$CHUNK 2>&1 >&$s8) == *0+0* ]] && break
#	[[ $(dd count=$CHUNK 2>&1 >&$s9) == *0+0* ]] && break
done 2>>$local_err

status=0
if [ -s $local_err ]
then
        echo "STREAMING ERROR DETECTED!"
        cat $local_err
        status=1
else
        echo "PURGE CHANGED_PAGE_BITMAPS BEFORE $(expr $last_lsn + 1)" | mysql -u $purge_user -h localhost -p$purge_pass
fi >> $log_file
exit $status
