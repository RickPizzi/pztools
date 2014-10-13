#!/bin/bash
#
#	MHA script to perform manual master failover when master is dead
#	rpizzi@blackbirdit.com
#
if [ $# -ne 2 ] 
then
	echo "usage: $0 [cluster-id] [dead master]"
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
	echo "specified master $2 not configured for this cluster"
	exit 1
fi
masterha_master_switch --master_state=dead --conf=/etc/mha_$1.cnf --dead_master_host=$2
exit 0
