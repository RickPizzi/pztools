#!/bin/bash
#
#	checks for proper completion of all backups
#	rpizzi@palominodb.com
#
DOMAIN=
#DUMPS_ENABLED=1
SERVERLIST="cluster1:10.17.54.10 cluster2:10.17.53.34 cluster3:10.17.5.17"
#
#
[ "$1" != "" ] && serverlist=$1
yesterday=$(date -d yesterday +%y%m%d)
today=$(date +%y%m%d)
for server in $SERVERLIST
do
	dbname=$(echo $server | cut -d":" -f 1)
	host=$(echo $server | cut -d":" -f 2)
	echo "Checking $dbname backups on $host$DOMAIN"
	status=$(ssh -Tq $host$DOMAIN | grep -v "^#")
	if [ $? -ne 0 ]
	then
 		echo "Connection error" 
		continue
	fi
	lastfull=$(echo $status | cut -d"|" -f 1)
	lastincr=$(echo $status | cut -d"|" -f 2)
	lastdump=$(echo $status | cut -d"|" -f 3)
	ok=0
	case "$lastfull" in
		'') lastfull='NEVER';;
		$today) lastfull='TODAY'; ok=1;;
		$yesterday) lastfull='YESTERDAY'; ok=1;;
	esac
	printf "%-8s %-8s last successful full backup was %s\n" $([ $ok -eq 1 ] && echo OK || echo ERROR) $dbname $lastfull
	ok=0
	case "$lastincr" in
		'') lastincr='NEVER';;
		$today) lastincr='TODAY'; ok=1;;
		$yesterday) lastincr='YESTERDAY';;
	esac
	printf "%-8s          last successful incr backup was %s\n" $([ $ok -eq 1 ] && echo OK || echo ERROR) $lastincr
	if [ $DUMPS_ENABLED ]
	then
		ok=0
		case "$lastdump" in
			'') lastdump='NEVER';;
				$today) lastdump='TODAY'; ok=1;;
			$yesterday) lastdump='YESTERDAY';;
		esac
		printf "%-8s          last successful dump taken %s\n" $([ $ok -eq 1 ] && echo OK || echo ERROR) $lastdump
	fi
done
