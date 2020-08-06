#!/usr/bin/env bash
###########################################################################
# Script:	zoneminder-event-cleanup.sh
# Purpose:	Clean up old Zoneminder events but exclude archived events
# Authors:	Claudio Kuenzler (2018)
# Doc:		https://www.claudiokuenzler.com/blog/814/how-to-manually-clean-up-delete-zoneminder-events
# History:	
# 2020-08-06 changed for zoneminder 1.24+ (@Brawn1)
# 2020-07-24 added Docker Mysql (@Brawn1)
# 2018-12-14 First version 
###########################################################################
# User variables
olderthan=7 # Defines the minimum age in days of the events to be deleted
zmcache=/var/lib/docker/volumes/zoneminder_zmcache/_data/events # Defines the path where zm stores events
mysqlhost=localhost # Defines the MySQL host for the zm database, if using Docker, set localhost
mysqldb=zm # Defines the MySQL database name used by zm
mysqluser=zoneminder # Defines a MySQL user to connect to the database
mysqlpass=zm-mysql-password # Defines the password for the MySQL user
docker_mysql="" # if mysql running as docker container, add the mysql container name (example: docker_mysql=zoneminder_mysql_1), or leafe it blank

# Fixed variables
tmpfile=/tmp/$RANDOM

if [[ ! -z ${docker_mysql} ]]; then
  # Get archived events from database
  declare -a archived=( $(docker exec -it ${docker_mysql} bash -lc 'mysql -N -h ${mysqlhost} -u ${mysqluser} --password=${mysqlpass} -e "select Id from ${mysqldb}.Events where Archived = 1;"') )
else
  # Get archived events from database
  declare -a archived=( $(mysql -N -h ${mysqlhost} -u ${mysqluser} --password=${mysqlpass} -e "select Id from ${mysqldb}.Events where Archived = 1;") )
fi

# Define find exceptions based on archived events
i=0
for id in $(echo ${archived[*]}); do
  findexception[$i]=" ! -name .${id}"
  let i++
done

# Find events according to our filter
find ${zmcache}/ -mindepth 3 -maxdepth 3 -type d -mtime +${olderthan} ${findexception[*]} -exec ls -ld {} + > $tmpfile

# For each found event...
while read line; do
  # Get the event ID
  eventid=$(echo $line | awk '{print $9}' | awk -F'/' '{print $NF}' | sed "s/\.//g")
  realpath=$(echo $line | awk '{print $9"/"$11}'  | sed "s/\.[0-9]*\///g")
  echo "Deleting Event $eventid"
  # delete events from disk and check if absolute path is similar to zmcache path (prevent to delete /)
  if [[ ${realpath} == ${zmcache}* ]]; then
    rm -rf ${realpath}
  fi
  # delete eventid from database
  if [[ ! -z ${docker_mysql} ]]; then
    docker exec -it ${docker_mysql} bash -lc 'mysql -h ${mysqlhost} -N -u ${mysqluser} --password=${mysqlpass} -e "DELETE FROM ${mysqldb}.Events where Id = $eventid"'
    docker exec -it ${docker_mysql} bash -lc 'mysql -h ${mysqlhost} -N -u ${mysqluser} --password=${mysqlpass} -e "DELETE FROM ${mysqldb}.Frames where EventId = $eventid"'
    docker exec -it ${docker_mysql} bash -lc 'mysql -h ${mysqlhost} -N -u ${mysqluser} --password=${mysqlpass} -e "DELETE FROM ${mysqldb}.Stats where EventId = $eventid"'
  else
    mysql -h ${mysqlhost} -N -u ${mysqluser} --password=${mysqlpass} -e "DELETE FROM ${mysqldb}.Events where Id = $eventid"
    mysql -h ${mysqlhost} -N -u ${mysqluser} --password=${mysqlpass} -e "DELETE FROM ${mysqldb}.Frames where EventId = $eventid"
    mysql -h ${mysqlhost} -N -u ${mysqluser} --password=${mysqlpass} -e "DELETE FROM ${mysqldb}.Stats where EventId = $eventid"
  fi
done < $tmpfile
exit 0
