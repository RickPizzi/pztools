#!/bin/bash
#
#	reports about replication lag highlighting both I/O thread and SQL thread lag
#	rpizzi@blackbirdit.com
#
#	note: reported lag is not 100% accurate due to data being sourced in different places
#
tmpf=/tmp/truelag$$
trap 'rm -f $tmpf' 0
datadir=$(fgrep datadir /etc/my.cnf | tr -d "[ ]" | cut -d"=" -f 2)
c=1
for row in $(cat $datadir/master.info  | head -6 | tail -3)
do
	case $c in
		1) master=$row;;
		2) user=$row;;
		3) pass=$row;;
	esac
	c=$(expr $c + 1)
done
( echo "show slave status\G" | mysql -Ar > $tmpf ) &
master_status=$(echo "show master status" | mysql -ANr -h $master -u $user -p$pass)
master_file=$(echo "$master_status" | cut -f 1)
master_pos=$(echo "$master_status" | cut -f 2)
wait
for row in $(cat $tmpf | tr -d "[ ]")
do
	var=$(echo $row | cut -d":" -f 1)
	val=$(echo $row | cut -d":" -f 2)
	case $var in
		'Master_Log_File') io_file=$val;;
		'Read_Master_Log_Pos') io_pos=$val;;
		'Relay_Master_Log_File') sql_file=$val;;
		'Exec_Master_Log_Pos') sql_pos=$val;;
	esac
done
sql_filenum=$(echo $sql_file | cut -d"." -f 2)
io_filenum=$(echo $io_file | cut -d"." -f 2)
master_filenum=$(echo $master_file | cut -d"." -f 2)
sql_poslag=$(expr $io_pos - $sql_pos)
sql_fnolag=$(expr $io_filenum - $sql_filenum)
io_poslag=$(expr $master_pos - $io_pos)
io_fnolag=$(expr $master_filenum - $io_filenum)
[ $io_fnolag -gt 0 ] && io_poslag="and some"
[ $sql_fnolag -gt 0 ] && sql_poslag="and some"
printf "Master:     %s %12d\n" $master_file $master_pos 
printf "I/O thread: %s %12d (%d binlogs %s events behind)\n" $io_file $io_pos $io_fnolag "$io_poslag"
printf "SQL thread: %s %12d (%d binlogs %s events behind)\n" $sql_file $sql_pos $sql_fnolag "$sql_poslag"
exit 0
