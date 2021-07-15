#!/bin/bash
#####################################################
# Cassandra Backup Script
# Infiniroot www.infiniroot.com
# 20210715 ck	First version
#####################################################
# Variables
nodetool=/usr/bin/nodetool
backuppath=/backup/cassandra
logpath=/var/log/cassandrabackup.log
#####################################################
if ! [[ -f ${logpath} ]]; then touch ${logpath}; fi
if ! [[ -d ${backuppath} ]]; then mkdir ${backuppath}; fi

(
# Define snapshotname
snapshotname=$(date +%Y%m%d%H%M)

# Create snapshot 
${nodetool} snapshot -t $snapshotname

snapshots=($(find /var/lib/cassandra/data/*/*/snapshots/ -name "$snapshotname"))

for snapshot in ${snapshots[*]}; do
	echo "Handling snapshot: $snapshot"
	dbname=$(echo $snapshot|awk -F'/' '{print $6}')
	tablename=$(echo $snapshot|awk -F'/' '{print $7}')
	echo "DB: $dbname, Table: $tablename"
	if ! [[ -d ${backuppath}/${dbname}/${tablename} ]]; then
		mkdir -p ${backuppath}/${dbname}/${tablename}
	fi
	echo "Starting rsync from $snapshot to ${backuppath}/${dbname}/${tablename}"
	/usr/bin/rsync -ao --delete --numeric-ids ${snapshot}/ ${backuppath}/${dbname}/${tablename}/
	if [[ $? -gt 0 ]]; then echo "ERROR during rsync on ${dbname}.${tablename}"; fi
	if [[ $? -eq 0 ]]; then echo "OK rsync ${dbname}.${tablename}"; fi
	echo "---------------------------------"

done

# Delete snapshot
${nodetool} clearsnapshot -t $snapshotname

) 2>&1 | tee -a ${logpath}
