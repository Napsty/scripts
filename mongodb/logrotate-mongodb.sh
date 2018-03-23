#!/bin/bash
#####################################################
# MongoDB Logrotate Script
# (c) Claudio Kuenzler
# 20150706 ck   Created script
#####################################################
# Variables
logpath=/var/log/mongodb
pidfile=/run/mongodb.pid
#####################################################
# Start
(
test -f $logpath/mongod.log || exit 1
echo "Starting MongoDB log rotation"
echo "Current logfile:"
ls -la $logpath/mongod.log
echo "Launching SIGUSR1 command"
kill -SIGUSR1 `cat $pidfile`
echo "Compressing new logfile"
find $logpath/ -name "mongod.log.$(date +%Y)*" ! -name "*.gz" -exec gzip {} +
echo "Finished MongoDB log rotation"
echo "-----------------------------------------------------"
) 2>&1 | tee -a ${logpath}/rotate.log
exit 0
