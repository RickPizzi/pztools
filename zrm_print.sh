#!/bin/bash
#
#	pretty prints ZRM backup status for all backup sets
# 	rpizzi@blackbirdit.com
#
TZ=$(date +%Z)
IFS="
"
for set in $(mysql-zrm-reporter backup-performance-info --fields backup-set --noheader 2> /dev/null | sort | uniq | sort)
do
    echo "Backup set: $set"
    echo "-------------------------------------------------------------------"
    for row in $(mysql-zrm-reporter backup-performance-info --fields backup-date,backup-level,backup-size,backup-status --noheader --where backup-set=$set 2>/dev/null | fgrep -v $TZ | fgrep -v REPORT)
    do
        type=$(echo $row | cut -c63-63)
        run=$(echo $row | cut -c78-79)
        echo $row
        [ $type -eq 0 -a $run != "--" ] && break
    done
    echo
done
