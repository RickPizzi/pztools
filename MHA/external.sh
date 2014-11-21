#!/bin/bash
#
#	MHA custom script for online master failover
#	rpizzi@blackbirdit.com
#
for arg in $*
do
	option=$(echo $arg | cut -d"=" -f 1)
	value=$(echo $arg | cut -d"=" -f 2)
	case "$option" in
		'--command') command="$value";;
		'--orig_master_ip') orig_ip="$value";;
		'--new_master_ip') new_ip="$value";;
		'--orig_master_user') orig_user="$value";;
		'--new_master_user') new_user="$value";;
		'--orig_master_password') orig_password=$(echo $value | tr -d "[\\\]");;
		'--new_master_password') new_password=$(echo $value | tr -d "[\\\]");;
	esac
done
case "$command" in
	'stop') echo "===> setting read_only=ON on current master"
		mysql -u $orig_user -h $orig_ip -p$orig_password -e "set global read_only=ON"
		;;
	'start') ;;
	*) echo "unknown command $command"; exit 1;;
esac
exit 0
