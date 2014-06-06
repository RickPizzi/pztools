#!/bin/bash
#       script called from archive server via ssh
#
lastfull=$(cat /var/log/mysql_full_backup.log 2>/dev/null | fgrep -i ": completed OK" | tail -1 | cut -d " " -f 1)
lastincr=$(cat /var/log/mysql_incremental_backup.log 2>/dev/null | fgrep -i ": completed OK" | tail -1 | cut -d " " -f 1)
lastdump=$(cat /var/log/mysql_dump.log 2>/dev/null | fgrep -i ": completed OK" | tail -1 | cut -d " " -f 1)
echo "# Backup status on $(hostname | cut -d"." -f1):"
echo "$lastfull|$lastincr|$lastdump"
exit 0
