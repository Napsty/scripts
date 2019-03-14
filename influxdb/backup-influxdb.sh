#!/bin/bash
#####################################################
# InfluxDB Dump Script
# www.infiniroot.com www.claudiokuenzler.com
# 20190314 ck	First version
#####################################################
# Variables
export PATH=$PATH
backuppath=/backup
logpath=/var/log/influxdump.log
database=ALL
INFLUX_USERNAME=
INFLUX_PASSWORD=
#####################################################
# Sanity checks
for cmd in influx influxd jshon
do
 if ! `which ${cmd} 1>/dev/null`
 then
 echo "ERROR: ${cmd} does not exist, please check if command exists and PATH is correct"
 exit ${STATE_UNKNOWN}
 fi
done
#####################################################
# Get user-given variables
while getopts "d:p:l:u:p:" Input;
do
  case ${Input} in
  d) database=${OPTARG};;
  p) backuppath=${OPTARG};;
  l) logpath=${OPTARG};;
  u) export INFLUX_USERNAME=${OPTARG};;
  p) export INFLUX_PASSWORD=${OPTARG};;
  *) echo -e "Usage: $0 [-d (dbname|ALL)] [-p backuppath] [-l logpath] [-u Influx user] [-p Influx password]. If no parameters are used, default is: $0 -d ALL -p /backup -l /var/log/influxdump.log"
     exit 1;;
  esac
done
#####################################################
# Start
(
echo "$(date): Backup script started."
if ! [[ -w ${backuppath} ]]; then 
  mkdir ${backuppath} 
  if ! [[ -w ${backuppath} ]]; then echo "ERROR: Unable to create ${backuppath}. Check permissions."; exit 1; fi
fi

echo "Clearing ${backuppath}"
rm -rf ${backuppath}/*

if [ "$database" = "ALL" ]; then 
  #databases=$(influx -execute 'show databases'  | sed "1,/----/d")
  echo "$(date): Starting Dump of all databases"
  time influxd backup -portable ${backuppath}
  echo "$(date): Finished Dump of all databases"
else
  echo "$(date): Starting Dump of $database"
  time influxd backup -portable -db $database ${backuppath}
  echo "$(date): Finished Dump of $database"
fi 

echo "$(date): Backup script finished."
echo "-----------------------------------------------------"
) 2>&1 | tee -a ${logpath}
 
exit $?
