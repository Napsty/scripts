#!/usr/bin/env bash
###########################################################################
# Script:	zoneminder-event-cleanup.sh
# Purpose:	Clean up old Zoneminder events but exclude archived events
# Authors:	Claudio Kuenzler (2018)
#           Guenter Bailey (2020)
# Doc:		https://www.claudiokuenzler.com/blog/814/how-to-manually-clean-up-delete-zoneminder-events
# History:
# 2018-12-14 First version
# 2018-12-18 DB Name variable in first query
# 2020-07-24 added Docker Mysql (@Brawn1)
# 2020-08-06 changed for zoneminder 1.24+ (@Brawn1)
# 2020-08-07 remove complexity and docker parts (@Brawn1)
###########################################################################
# User variables
olderthan=2 # Defines the minimum age in days of the events to be deleted
zmcache=/var/cache/zoneminder/events # Defines the path where zm stores events
mysqlhost=localhost # Defines the MySQL host for the zm database
mysqldb=zm # Defines the MySQL database name used by zm
mysqluser=zoneminder # Defines a MySQL user to connect to the database
mysqlpass=zm-mysql-password # Defines the password for the MySQL user
zm_linked_version="" # set "true" if using zoneminder pre 1.24 (old version with symlinks instead directories by events)

# Fixed variables
tmpfile=/tmp/$RANDOM

# Get archived events from database
declare -a archived=( $(mysql -N -h ${mysqlhost} -u ${mysqluser} --password=${mysqlpass} -e "select Id from ${mysqldb}.Events where Archived = 1;") )

# Define find exceptions based on archived events
i=0
for id in $(echo ${archived[*]}); do
  findexception[$i]=" ! -name .${id}"
  let i++
done

# Find events according to our filter
if [[ ! -z ${zm_linked_version} ]]; then
  find ${zmcache}/ -mindepth 2 -type l -mtime +${olderthan} ${findexception[*]} -exec ls -la {} + > $tmpfile
else
  find ${zmcache}/ -mindepth 3 -maxdepth 3 -type d -mtime +${olderthan} ${findexception[*]} -exec ls -ld {} + > $tmpfile
fi

# For each found event...
while read line; do
  # Get the event ID
  eventid=$(echo $line | awk '{print $9}' | awk -F'/' '{print $NF}' | sed "s/\.//g")
  realpath=$(echo $line | awk '{print $9"/"$11}'  | sed "s/\.[0-9]*\///g")
  echo "Deleting Event Id=$eventid"
  
  if [[ ! -z ${zm_linked_version} ]]; then
    symlink=$(echo $line | awk '{print $9}')
    rm -f ${symlink}
  fi
  
  # delete events from disk and check if absolute path is similar to zmcache path (prevent to delete /)
  if [[ ${realpath} == ${zmcache}* ]]; then
    rm -rf ${realpath}
  fi
  
  # delete eventid from database
  mysql -h ${mysqlhost} -N -u ${mysqluser} --password=${mysqlpass} -e "DELETE FROM ${mysqldb}.Events where Id = $eventid"
  mysql -h ${mysqlhost} -N -u ${mysqluser} --password=${mysqlpass} -e "DELETE FROM ${mysqldb}.Frames where EventId = $eventid"
  mysql -h ${mysqlhost} -N -u ${mysqluser} --password=${mysqlpass} -e "DELETE FROM ${mysqldb}.Stats where EventId = $eventid"
done < $tmpfile

exit 0
