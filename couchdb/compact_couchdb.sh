#!/bin/bash
#########################################################################
# CouchDB compact script
# This script will go through all databases and views and compact them
# Script is maintained here: https://github.com/Napsty/scripts
#
# License: GPLv2
#
# GNU General Public Licence (GPL) http://www.gnu.org/
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, see <https://www.gnu.org/licenses/>.
#
# Copyright (c) 2018,2020 Claudio Kuenzler www.claudiokuenzler.com
#
# History:
# 2018-07-19 Created script
# 2020-02-28 Catch several http errors (fix issue-3)
# 2020-02-28 Add "-k" parameter to ignore certificate errors
#########################################################################
# Assume defaults
cdbproto=http
cdbhost=localhost
cdbport=5984
#########################################################################
# Functions
help() {
echo -e "$0 (c) 2018-2020 Claudio Kuenzler www.claudiokuenzler.com
This script helps to compact databases and views on a CouchDB server.
Please note that a recent version of CouchDB should be used (due to the _design_docs parameter). 
The script was tested with CouchDB 2.1. Newer versions _should_ work, too.
---------------------
     -H Hostname or ip address of CouchDB Host (defaults to localhost)
     -P Port (defaults to 5984)
     -S Use https
     -k Ignore certificate errors
     -u Username if authentication is required
     -p Password if authentication is required
     -d Debug (shows some additional information)
     -h Help!
---------------------
Usage: $0 [-H MyCouchDBHost] [-P port] [-S] [-u user] [-p pass] [-d]
---------------------
Cronjob example 1: 00 03 * * 7 /root/scripts/compact_couchdb.sh -H remoteserver -P 5984 -u admin -p mysecretpass
Cronjob example 2: 00 03 * * 7 /root/scripts/compact_couchdb.sh

Requirements: curl, jshon, tr"
exit 3;
}

authlogic () {
if [[ -z $user ]] && [[ -z $pass ]]; then echo "Error - Authentication required but missing username and password"; exit 3
elif [[ -n $user ]] && [[ -z $pass ]]; then echo "Error - Authentication required but missing password"; exit 3
elif [[ -n $pass ]] && [[ -z $user ]]; then echo "Error - Missing username"; exit 3
fi
}
#########################################################################
# Check requirements
for cmd in curl jshon; do
 if ! `which ${cmd} 1>/dev/null`; then
   echo "UNKNOWN: ${cmd} does not exist, please check if command exists and PATH is correct"
   exit 3
 fi
done
#########################################################################
# Get user-given variables
while getopts "H:P:Su:p:r:dkh" Input;
do
  case ${Input} in
  H)      cdbhost=${OPTARG};;
  P)      cdbport=${OPTARG};;
  S)      cdbproto=https;;
  u)      user=${OPTARG};;
  p)      pass=${OPTARG};;
  d)      debug=1;;
  k)      verify="-k";;
  h)      help;;
  *)      help;;
  esac
done
#########################################################################
if [[ -n $user ]] && [[ -n $pass ]]
  then authlogic
  cdbcreds="-u ${user}:${pass}"
fi
 
curldbs=$(curl -q -s $verify ${cdbproto}://${cdbhost}:${cdbport}/_all_dbs ${cdbcreds})
curldbsrc=$?

if [[ $curldbsrc -eq 6 ]]; then 
  echo "Error: Could not resolve host: ${cdbhost}"; exit 2
elif [[ $curldbsrc -eq 7 ]]; then
  echo "Error: Failed to connect to ${cdbhost}:${cdbport}"; exit 2
elif [[ $curldbsrc -eq 60 ]]; then
  echo "Error: Certificate very failed on ${cdbhost}:${cdbport}"; exit 2
elif [[ ${curldbs} =~ "unauthorized" ]] || [[ ${curldbs} =~ "Authorization" ]]; then
  echo "Error: Unauthorized to run compact. Make sure you are using server admin credentials."; exit 2
else declare -a dbs=( $(echo $curldbs|jshon -a -u) )
fi

if [[ $debug -eq 1 ]]; then echo "Found ${#dbs[*]} databases"; fi

i=0
for db in ${dbs[*]}; do
 
  if [[ -n $(echo $db | egrep "^_") ]]
    then 
    if [[ $debug -eq 1 ]]; then echo "Found a system database. Skipping $db."; fi
  else
    if [[ $debug -eq 1 ]]; then 
      echo "Running compact on $db"
      echo curl -q -s -H "Content-Type: application/json" -X POST ${cdbproto}://${cdbhost}:${cdbport}/${db}/_compact ${cdbcreds}
    fi
    compactresult=$(curl -q -s -H "Content-Type: application/json" -X POST ${cdbproto}://${cdbhost}:${cdbport}/${db}/_compact ${cdbcreds})

    if [[ ${compactresult} =~ "unauthorized" ]]
      then echo "Error: Unauthorized to run compact. Make sure you are using server admin credentials."; exit 2
    elif [[ ${compactresult} =~ "ok" ]] && [[ $debug -eq 1 ]]
      then echo "Compacting of ${db} successfully started"
    fi 
  
    if [[ $debug -eq 1 ]]; then echo "Getting list of views of $db"; fi
    declare -a views=( $(curl -q -s ${cdbproto}://${cdbhost}:${cdbport}/${db}/_design_docs ${cdbcreds}|jshon -e rows -a -e id -u|awk -F '/' '{print $2}') )

    if [[ $debug -eq 1 ]]; then echo "Found ${#views[*]} view(s) in $db: ${views[*]}"; fi
  
    for view in ${views[*]}; do
      if [[ $debug -eq 1 ]]; then 
        echo "Running compact on view $view"
        echo curl -q -s -H "Content-Type: application/json" -X POST ${cdbproto}://${cdbhost}:${cdbport}/${db}/_compact/${view} ${cdbcreds}
      fi
      curl -q -s -H "Content-Type: application/json" -X POST ${cdbproto}://${cdbhost}:${cdbport}/${db}/_compact/${view} ${cdbcreds}
    done
  fi

done
