#!/bin/bash
#
#	buffer pool warmer
#	picks traffic from one server and replicates it to another one, checking for
#	number of new slow queries and acting upon it
#
#	when max $target new slow queries are recorded on target server for $minok consecutive
#	times, the target buffer pool is considered warm.
#	pt-query-digest is killed and restarted at every iteration because otherwise a single
#	long running query would delay the iteration and weaken script's effectiveness
#
#	rpizzi@blackbirdit.com
#
SRC_DSN="h=1.2.3.4,u=root,p=XXXX"
DSTUSER=root
DSTPASS=XXXXX
DSTHOST=localhost
#
#
target=0 # how many new slow queries are acceptable to mark one iteration OK (max)
minok=3  # number of consecutive OK iterations to end script (DB is warm)
grace=36 # number of initial iterations where we don't check anything 
max_time=600 # exit after this time has elapsed, in seconds, even if DB not warm
#
dst_dsn="h=$DSTHOST,u=$DSTUSER,p=$DSTPASS"
lastsq=0
ok=0
start=$(date +%s)
timelimit=$(expr $start + 600)
while true
do
	/usr/bin/pt-query-digest --processlist $SRC_DSN --interval 1 --filter '$event->{arg} =~ m/^SELECT/i' --execute $dst_dsn >/dev/null 2>&1 &
	pid=$!
	echo "spawned pt-query-digest pid $pid"
	sq=$(mysqladmin -h localhost -u root -p$PASS status | cut -d " " -f 12)
	echo "current slow query counter value $sq"
	if [ $grace -gt 0 ]
	then
		grace=$(expr $grace - 1)
		echo "sleeping 5 seconds (grace period)"
	else
		if [ $lastsq -gt 0 ]
		then
			diff=$(expr $sq - $lastsq)
			echo "found $diff new slow queries"
			if [ $diff -le $target ]
			then
				ok=$(expr $ok + 1)
				if [ $ok -eq $minok ]
				then
					break
				else
					echo target $target met, $ok/$minok
				fi
			else
				echo target is $target, not met
				ok=0
			fi
		fi
		lastsq=$sq
		echo "sleeping 5 seconds"
	fi
	sleep 5
	echo "killing query digest pid $pid"
	kill -9 $pid # -9 needed here
	curtime=$(date +%s)
	if [ $curtime -gt $timelimit ]
	then
		echo "time limit of $max_time seconds reached, exiting"
		exit 0
	fi
done 2>/dev/null
echo "target of $target met $ok/$minok - done"
exit 0
