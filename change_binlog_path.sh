#!/bin/bash
#
# script that changes the path where the binlogs are being written without stopping the server or the service,
# by using a symbolic link 
#
# (C) pizzi@leopardus.com Sept-2016
#
# Step 1: configure the variable below to point to new path
# Step 2: run the script as root, after ensuring that the binlog being written has just been opened, because you need some 
#         time for next step.
# Step 3: issue a FLUSH BINARY LOG on the server, it will start writing the binlogs in the new path
#
# Note: slave(s) may be affected by the operation; to recover, just issue a STOP SLAVE; START SLAVE and that will clear the error
#
#
NEW_BINLOG_DIR=/db/binlog2
#
binlog_dir=$(dirname $(grep "log_bin" /etc/my.cnf | cut -d "=" -f 2 | tr -d " "))
binlog_base=$(basename $(grep "log_bin" /etc/my.cnf | cut -d "=" -f 2 | tr -d " "))
curbin=$(cat $binlog_dir/$binlog_base.index | tail -1 | cut -d "." -f 2)
touch $NEW_BINLOG_DIR/$binlog_base.$curbin
mv $binlog_dir ${binlog_dir}_orig 
ln -s $NEW_BINLOG_DIR $binlog_dir
exit 0
