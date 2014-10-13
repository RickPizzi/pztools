#!/bin/bash
#
#	MHA script to perform manual master failover
#	rpizzi@blackbirdit.com
#
if [ $# -ne 2 ] 
then
	echo "usage: $0 [cluster-id] [new master]"
	exit 1
fi
if [ ! -f /etc/mha_$1.cnf ] 
then
	echo "cluster-id $1 not found"
	exit 1
fi
check=$(grep "^hostname=$2\$" /etc/mha_$1.cnf)
if [ "$check" = "" ]
then
	echo "candidate master $2 not configured"
	exit 1
fi
masterha_master_switch --master_state=alive --conf=/etc/mha_$1.cnf --new_master_host=$2 --orig_master_is_new_slave
exit 0
