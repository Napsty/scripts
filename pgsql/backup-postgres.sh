#!/bin/bash
#####################################################
# Postgres Dump Script
# www.infiniroot.com www.claudiokuenzler.com
# 20130724 ck	First version
# 20130726 ck	Bugfix
# 20130805 ck	Bugfix in gzip
# 20141009 ck	Added -b to dump blobs, too
# 20190314 ck   Make script more dynmamic, public release
#####################################################
# Variables and defaults
export PATH=$PATH
backuppath=/backup
logpath=/var/log/pgdump.log
database=ALL
#####################################################
# Sanity checks
for cmd in psql pg_dump
do
 if ! `which ${cmd} 1>/dev/null`
 then
 echo "ERROR: ${cmd} does not exist, please check if command exists and PATH is correct"
 exit ${STATE_UNKNOWN}
 fi
done
#####################################################
# Get user-given variables
while getopts "d:p:l:" Input;
do
  case ${Input} in
  d) database=${OPTARG};;
  p) backuppath=${OPTARG};;
  l) logpath=${OPTARG};;
  *) echo -e "Usage: $0 [-d (dbname|ALL)] [-p destinationpath] [-l logpath]. If no parameters are used, default is: $0 -d ALL -p /backup -l /var/log/pgdump.log"
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

if [ "$database" = "ALL" ]; then 
  databases=$(psql -U postgres -c "SELECT datname FROM pg_database" -t -A | grep -v template0)
else
  databases=$database
fi 
 
for db in $databases; do
echo "$(date): Starting Dump of $db"
test -f ${backuppath}/$db.pgdump.gz && rm ${backuppath}/$db.pgdump.gz
time pg_dump -U postgres -Fc -b -f ${backuppath}/$db.pgdump $db
test -f ${backuppath}/$db.pgdump && gzip ${backuppath}/$db.pgdump
echo "$(date): Finished Dump of $db"
echo "----------------"
done
 
echo "$(date): Backup script finished."
echo "-----------------------------------------------------"
) 2>&1 | tee -a ${logpath}
 
exit $?
