#!/bin/bash
#
# magic change master: repoint a slave to a different galera master automatically
#
#	script will look up the specified slave position and find out the change master command to repoint the slave for you
#	usage:  magic_change_master.sh <slave to repoint> <new master> [ dead ]"
#		if dead parameter is specified, script assumes master dead and uses the slave relay log to find out galera Xid
#
if [ "$2"  = "" ]
then
    echo "Usage: $0 <slave name> <new master> [ dead ]"
    exit 1
fi
new_master=$(host $2 | fgrep address | cut -d " " -f 4)
[ "$new_master" = "" ] && new_master=$2
curpos=($(echo "show slave status\G" | ssh -tq $1 mysql -Ar | egrep " Master_Host| Master_Log_File| Exec_Master_Log_Pos| Relay_Log_File| Relay_Log_Pos" | cut -d ":"  -f 2))
master=${curpos[0]}
if [ "$master" = "$new_master" ]
then
    echo "Cannot change master to the current master"
    exit 1
fi
binlog=${curpos[1]}
relay=${curpos[2]}
relay_pos=${curpos[3]}
exec_pos=${curpos[4]}
echo "On slave $1, current situation is: Master $master, File $binlog, Position $exec_pos"
binlog_base=$(echo "select @@log_bin_basename" | ssh -tq $master mysql -ANr)
relay_base=$(echo "select @@datadir" | ssh -tq $master mysql -ANr)
if [ "$3" = "dead" ]
then
    echo -n "looking up Xid in relay log for position $exec_pos... "
    xid=$(ssh -tnq $1 sudo mysqlbinlog $relay_base/$relay | fgrep "end_log_pos $exec_pos " | cut -d"=" -f 2 | tr -d " ")
else
    echo -n "looking up Xid in $binlog for position $exec_pos... "
    xid=$(ssh -tnq $master sudo mysqlbinlog $(dirname $binlog_base)/$binlog | fgrep "end_log_pos $exec_pos " | cut -d"=" -f 2 | tr -d " ")
fi
echo $xid
binlog_base=$(echo "select @@log_bin_basename" | ssh -tq $new_master mysql -ANr)
echo -n "searching binlogs on $2 using Xid range search... "
for b in $(ssh -tq $new_master ls -t $binlog_base*.[0-9]*)
do
    new_pos_binlog=$(basename $b)
    echo -n $new_pos_binlog" "
    bxid=$(ssh -tnq $new_master sudo mysqlbinlog $b | fgrep  -m 1 "Xid = " | cut -d "=" -f 2 | tr -d " ")
    if [ "$bxid" = "" ] 
    then
	echo " FAILED! Check that passwordless sudo is enabled!"
	exit 1
    fi
    [ $bxid -lt $xid ] && break
done
echo
echo -n "looking up position in $new_pos_binlog for Xid $xid... "
new_pos=$(ssh -tnq $new_master sudo mysqlbinlog $b | fgrep "Xid = $xid" | tr -s " " | cut -d " " -f 7)
echo $new_pos
echo "All done! Connect to $1 and issue: CHANGE MASTER TO MASTER_HOST='$new_master', MASTER_PORT=3306, MASTER_LOG_FILE='$new_pos_binlog', MASTER_LOG_POS=$new_pos"
exit 0
