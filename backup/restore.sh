#!/bin/bash
#
#	backup restore script
#	v 2.21 Sep 2014
#	rpizzi@blackbirdit.com
#	looks at default files to find archive server, etc
#	then hunts for more recent full backup and restores up to latest hourly incremental
#
#	parameters:
#	$1 = datadir  (where you want to restore the backup)
#
#       restore sequence
#
#       1 - full (latest one found on archive server)
#       2 - daily deltas  (consolidated backups)
#       3 - hourly deltas (hourly incrementals)
#
#
DEFAULTS=/etc/default/backup_full
KEY=/home/mysql_backup/.ssh/id_rsa
MEMORY=20GB
log=./backup.log
#
if [ $# -ne 1 ] 
then
	echo "usage: $0 <datadir>"
	exit 1
fi
if [ -d $1 ] 
then
	echo "datadir $1 must not exist"
	exit 1
fi
mkdir -p $1
if [ $? -ne 0 ]
then
	echo "error creating datadir $1"
	exit 1
fi
tmpf=/tmp/restore.$$
trap 'rm -f $tmpf' 0
remote_server=$(grep "^remote_server=" $DEFAULTS | cut -d"=" -f 2)
remote_path=$(grep "^remote_path=" $DEFAULTS | cut -d"=" -f 2)
remote_user=$(grep "^remote_user=" $DEFAULTS | cut -d"=" -f 2)
xtrabackup=$(grep "^xtrabackup=" $DEFAULTS | cut -d"=" -f 2)
lastfull=$(ssh -q -i $KEY $remote_user@$remote_server "find $remote_path -type f -name FS\* ! -mmin -60" | tail -1)
if [ "$lastfull" = "" ]
then
	echo "unable to autodetect last full backup"
	exit 1
fi
offset=$(echo $remote_path | tr -s "[/]" "[\n]" | wc -l)
fulldate=$(echo $lastfull | cut -d"/" -f $(expr 1 + $offset)-$(expr 3 + $offset))
consolidated=$(ssh -q -i $KEY $remote_user@$remote_server "find $remote_path -type f -name delta_consolidated\* -newer $lastfull ! -mmin -60")
incrementals=$(ssh -q -i $KEY $remote_user@$remote_server "find $remote_path -type f -name delta_inc\* -newer $lastfull ! -mmin -30")
n_cons=$(echo $consolidated | wc -w)
n_incr=$(echo $incrementals | wc -w)
echo "*** Phase I -- Full Backup"
echo "**** Copying full backup dated $fulldate"
ssh -q -i $KEY $remote_user@$remote_server cat $lastfull | zcat | xbstream -x -C $1
if [ $? -ne 0 ]
then
	echo "error copying full backup, aborting"
	exit 1
fi
echo "**** Processing full backup"
$xtrabackup --defaults-file=$1/backup-my.cnf --prepare  --use-memory=$MEMORY --apply-log-only --target-dir=$1 > $log 2>&1
if [ $? -ne 0 ]
then
	echo "error processing full backup, aborting"
	echo
	cat $log
	exit 1
fi
echo "*** Phase II -- Consolidated Daily Backups"
if [ $n_cons -gt 0 ]
then
	echo "**** Processing $n_cons consolidated backup(s)"
        last_cons=$(echo $consolidated | tr "[ ]" "[\n]" | tail -1 | cut -d "." -f 2)
	for piece in $consolidated
	do
		name=$(echo $piece | cut -d "." -f 2)
		echo "**** Copying $name"
		mkdir -p $1/consolidated/$name
		ssh -q -i $KEY $remote_user@$remote_server zcat $piece | xbstream -x -C $1/consolidated/$name 
		if [ $? -ne 0 ]
		then
			echo "error copying consolidated $name, aborting"
			exit 1
		fi
	done
	for piece in $(ls $1/consolidated)
	do
		echo "**** Applying consolidated $piece"
		$xtrabackup --defaults-file=$1/backup-my.cnf --prepare  --use-memory=$MEMORY --apply-log-only --target-dir=$1 --incremental-dir=$1/consolidated/$piece > $log 2>&1
		if [ $? -ne 0 ]
		then
			echo "error applying consolidated $piece, aborting"
			echo
			cat $log
			exit 1
		fi
	done
fi
echo "*** Phase III -- Incremental Hourly Backups"
if [ $n_incr -gt 0 ]
then
	echo "**** Processing $n_incr incremental backup(s)"
        last_incr=$(echo $incrementals | tr "[ ]" "[\n]" | tail -1 | cut -d "." -f 2)
	for piece in $incrementals
	do
		name=$(echo $piece | cut -d "." -f 2)
		echo "**** Copying $name"
		mkdir -p $1/incrementals/$name
		# originally one pipeline, but xbstream has a bug and does not notice 
		# broken pipes...
		ssh -q -i $KEY $remote_user@$remote_server cat $piece | zcat > $1/incrementals/$name/piece.xbs 2>$tmpf
		if [ $? -ne 0 ]
		then
			echo "error transferring incremental $name: $(cat $tmpf)"
			if [ "$name" = "$last_incr" ] 
			then
				echo "maybe interrupted backup, but "
				echo "this piece was needed for binlog position. aborting."
				echo "suggestion: remove it and rerun restore".
				exit 1
			fi
			echo "assuming interrupted backup, skipping this piece. be careful."
			rm -r $1/incrementals/$name
			continue
		fi
		cat $1/incrementals/$name/piece.xbs | xbstream -x -C $1/incrementals/$name
		if [ $? -ne 0 ]
		then
			echo "error extracting incremental $name, aborting"
			exit 1
		fi
		rm $1/incrementals/$name/piece.xbs
	done
	for piece in $(ls $1/incrementals)
	do
		echo "**** Applying incremental $piece"
		$xtrabackup --defaults-file=$1/backup-my.cnf --prepare  --use-memory=$MEMORY --apply-log-only --target-dir=$1 --incremental-dir=$1/incrementals/$piece > $log 2>&1
		if [ $? -ne 0 ]
		then
			echo "error applying incremental $piece, aborting"
			echo
			cat $log
			exit 1
		fi
	done
fi
echo "*** Phase IV -- Final preparation"
$xtrabackup --defaults-file=$1/backup-my.cnf --prepare --use-memory=$MEMORY --target-dir=$1 > $log 2>&1
if [ $? -ne 0 ]
then
	echo "error during final prepare, aborting"
	echo
	cat $log
	exit 1
fi
# get latest information about binlog pos, partitions and table fmt from last backup piece
if [ "$last_incr" != "" ]
then
	cp $1/incrementals/$last_incr/xtrabackup_binlog_info $1
	cp $1/incrementals/$last_incr/xtrabackup_slave_info $1
	cd $1/incrementals/$last_incr
	for f in $(find . -name \*frm -o -name \*par | cut -d "/" -f 2-)
	do
		cp $1/incrementals/$last_incr/$f $1/$f
	done
else
	if [ "$last_cons" != "" ]
	then
		cp $1/consolidated/$last_cons/xtrabackup_binlog_info $1
		cp $1/consolidated/$last_cons/xtrabackup_slave_info $1
		cd $1/consolidated/$last_cons
		for f in $(find . -name \*frm -o -name \*par | cut -d "/" -f 2-)
		do
			cp $1/consolidated/$last_cons/$f $1/$f
		done
	fi
fi
echo "*** Phase V -- Cleanup"
rm -rf $1/consolidated $1/incrementals
echo "*** Done. Don't forget to change ownership of files on $1 before starting mysqld."
exit 0
