#!/bin/bash
#
#	rpizzi@blackbirdit.com
#	reports interesting INNODB errors from output of SHOW ENGINE INNODB
#	Tested with 5.1 and 5.5
#
#	db.conf format:
#	nickname:hostname or IPaddr:path-to-mysql-sock
#
#	script assumes that the user which is running under has ssh and sudo access to the DB servers
#	if not, tweaks are needed 
#
DBLIST=db.conf
WANTED="LATEST FOREIGN KEY ERROR|LATEST DETECTED DEADLOCK"
#
tmpf=/tmp/innomon.$$
trap 'rm -f $tmpf' 0
savedir=/tmp/innodbmon_saves
[ ! -d $savedir ] && mkdir $savedir
IFS="
"
something_found=0
for db in $(grep -v "^#" $DBLIST)
do
	nickname=$(echo $db | cut -d":" -f 1)
	host=$(echo $db | cut -d":" -f 2)
	socket=$(echo $db | cut -d":" -f 3)
	ssh -q $host "sudo su - -c \"echo 'show engine innodb status' | mysql -A -N -r -u root -S $socket\"" > $tmpf 2>/dev/null
	if [ ! -s $tmpf ] 
	then
		echo
		echo "ERROR: unable to fetch data from $nickname ($host)"
		continue
	fi
	parsing_hdr=0
	fake=0
	wantit=0
	capture_ts=0
	for row in $(cat $tmpf | sed -e "s/^=====/-----/g")
	do
		hdr=$(echo $row | cut -c1-5)
		if [ $hdr = "---OL" ]
		then
			hdr="-----"
			fake=1
		fi
		if [ $hdr = "-----" ]
		then
			if [ $parsing_hdr -eq 0 ]
			then
				parsing_hdr=1
				wantit=0
			else
				parsing_hdr=0
				fake=0
			fi
			continue
		fi
		if [ $parsing_hdr -eq 1 ]
		then
			[ $fake -eq 1 ] && continue
#			echo "HEADER: $row ($nickname)"
			wantit=$(echo $row | egrep -c "$WANTED")
			if [ $wantit -eq 1 ]
			then
				curr_header="$row"
				capture_ts=1
			fi
			continue
		fi
		if [ $wantit -eq 1 ]
		then
			if [ $capture_ts -eq 1 ]
			then
				header_fn=$(echo $curr_header | tr "[:upper:]" "[:lower:]" | tr -s "[ ]" "[_]")
				timestamp=$(echo $row | cut -d" " -f 1,2)
				if [ -f $savedir/${nickname}_${header_fn} ]
				then
					last_timestamp=$(cat $savedir/${nickname}_${header_fn}) 
					if [ "$last_timestamp" = "$timestamp" ]
					then
						#echo "ALREADY SEEN $curr_header"
						wantit=0
						continue
					fi
				fi
				echo
				echo	"==============================="
				echo	"DB: $nickname"
				echo	"TYPE: $curr_header"
				echo	"TIMESTAMP: $timestamp"
				echo	"==============================="
				echo
				echo $timestamp > $savedir/${nickname}_${header_fn}
				capture_ts=0
				something_found=1
				continue
			fi
			echo "$row"
		fi
	done
done
if [ $something_found -eq 0 ]
then
	echo
	echo	"No new errors have been found."
fi
exit 0
