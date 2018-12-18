#!/usr/bin/env bash
###########################################################################
# Script:	zoneminder-event-cleanup.sh
# Purpose:	Clean up old Zoneminder events but exclude archived events
# Authors:	Claudio Kuenzler (2018)
# Doc:		https://www.claudiokuenzler.com/blog/814/how-to-manually-clean-up-delete-zoneminder-events
# History:	
# 2018-12-14 First version
# 2018-12-18 DB Name variable in first query
###########################################################################
# User variables
olderthan=2 # Defines the minimum age in days of the events to be deleted
zmcache=/var/cache/zoneminder/events # Defines the path where zm stores events
mysqlhost=localhost # Defines the MySQL host for the zm database
mysqldb=zm # Defines the MySQL database name used by zm
mysqluser=zmuser # Defines a MySQL user to connect to the database
mysqlpass=secret # Defines the password for the MySQL user

# Fixed variables
tmpfile=/tmp/$RANDOM

# Get archived events from database
declare -a archived=( $(mysql -N -u $mysqluser --password=$mysqlpass -e "select Id from ${mysqldb}.Events where Archived = 1;") )

# Define find exceptions based on archived events
i=0
for id in $(echo ${archived[*]}); do
  findexception[$i]=" ! -name .${id}"
  let i++
done

# Find events according to our filter
find ${zmcache}/ -mindepth 2 -type l -mtime +${olderthan} ${findexception[*]} -exec ls -la {} + > $tmpfile

# For each found event...
while read line; do
  # Get the event ID
  symlink=$(echo $line | awk '{print $9}')
  eventid=$(echo $line | awk '{print $9}' | awk -F'/' '{print $NF}' | sed "s/\.//g")
  realpath=$(echo $line | awk '{print $9"/"$11}'  | sed "s/\.[0-9]*\///g")
  echo "Deleting $eventid"
  rm -rf $realpath
  rm -f $symlink
  mysql -h $mysqlhost -N -u $mysqluser --password=$mysqlpass -e "DELETE FROM ${mysqldb}.Events where Id = $eventid"
  mysql -h $mysqlhost -N -u $mysqluser --password=$mysqlpass -e "DELETE FROM ${mysqldb}.Frames where EventId = $eventid"
  mysql -h $mysqlhost -N -u $mysqluser --password=$mysqlpass -e "DELETE FROM ${mysqldb}.Stats where EventId = $eventid"
done < $tmpfile

exit 0
