#!/bin/bash
###############################################################
# Script:       pdns-search-replace.sh
# Author:       Claudio Kuenzler (www.claudiokuenzler.com)
# Description:  pdns-search-replace.sh is a script which allows
# you to quickly update DNS records on a PowerDNS server with
# a MySQL backend. 
# The script will search for the given search string (-s string)
# and replace it by the replace string (-r string). 
# It will then increase the serial of the affected zone and 
# issue a notify command (for the slaves to update the zone).
###############################################################
# Changelog:
# 2021-03-02 ALPHA
# 2022-06-09 Added several options (-H, -t, -n)
#            Made 'replace' mandatory
#            Changed invocation of mysql* commands
#            Changed behaviour after update
#            (author: Frank Maas)
# 2023-10-05 Bugfix when using dash in database name
###############################################################
# License:      GNU General Public Licence (GPL) http://www.gnu.org/
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, see <https://www.gnu.org/licenses/>.
###############################################################
# Version
version="ALPHA 2.1"

# Defaults and assumptions
dbname="powerdns"
dbport=3306
dbhost="localhost"
myts=$(date +%s)
slaves=true
batchmode=false
dryrun=false
###############################################################

# Help 
help="$0 $version (c) 2021-2023 Claudio Kuenzler\n
Usage: $0 -s searchstring -r replacestring\n
Options:
-s Search for this particular string
-r Replace the search string with this string (use '' to remove search string)
-d Database name (default: powerdns)
-u Database user
-p Database password
-H Database host (default: localhost)
-P Database port (default: 3306)
-n Do not notify slaves/No slaves present
-B Enable batch mode
-t Testrun (only report number of domains that would be changed)
-h Show help\n
Requirements: mysql, pdns_util, pdns_control\n"


# Check for people who need help - aren't we all nice ;-)
if [ "${1}" = "--help" ] || [ "${#}" = "0" ];
       then
       echo -e "${help}";
       exit 1;
fi
###############################################################
# Get user-given variables
while getopts "s:r:d:u:p:P:H:Btn" Input;
do
       case ${Input} in
       s)      search=${OPTARG};;
       r)      replace=${OPTARG};;
       d)      dbname=${OPTARG};;
       u)      dbuser=${OPTARG};;
       p)      dbpass=${OPTARG}; export MYSQL_PWD="${OPTARG}";;
       P)      dbport=${OPTARG};;
       H)      dbhost=${OPTARG};;
       B)      batchmode=true;;
       t)      dryrun=true;;
       n)      slaves=false;;
       h)      echo -e "${help}"; exit 1;;
       *)      echo -e "${help}"; exit 1;;
       esac
done

###############################################################
# Check for required parameters
if [[ -z ${search} ]]; then
  echo "Missing search string (-s)"; exit 2
fi

if [[ -z ${replace} ]]; then
  echo "Missing replace string (-r)"; exit 2
fi

if [[ -z ${dbuser} ]]; then
  echo "Missing database user (-u)"; exit 2
fi
###############################################################
# Set mysql parameters (all parameters default or mandatory)
dbparam="-h ${dbhost} -P ${dbport} -u ${dbuser} ${dbname}"
###############################################################
# Ask for backup when launching interactive
if [[ ${batchmode} == false && ${dryrun} == false  ]]; then
  read -p "Manipulating DNS records can cause severe damage in your zone. Would you like to create a backup first? Y/N ? " reply
  case $reply in 
    [Yy]* ) echo "Saving MySQL dump of ${dbname} in /tmp/${dbname}.${myts}.sql"
          mysqldump ${dbparam} > /tmp/${dbname}.${myts}.sql
          if [[ $? -gt 0 ]]; then echo "There was a problem creating a backup. Exiting."; exit 2; fi
          if ! [[ -s /tmp/${dbname}.${myts}.sql ]]; then echo "Dump is empty. Not good. Do a manual backup. Exiting."; exit 2; fi
          ;;
    [Nn]* ) echo "You like to live dangerously, eh?" ;;
  esac
fi
###############################################################
# Do da magic
declare -a affecteddomains=($(mysql ${dbparam} -Bse "SELECT domain_id FROM \`${dbname}\`.records WHERE content LIKE '%${search}%'" | uniq | tr '\n' ' '))

if [[ $? -gt 0 ]]; then
  echo "Unable to connect to database"; exit 2
fi

if [[ ${#affecteddomains[*]} -eq 0 ]]; then
  echo "Found no domains containing '${search}': nothing to do"
  exit 0
else
  echo "Found ${#affecteddomains[*]} domains that will be affected of '${search}' being replaced by '${replace}'"
fi

# Check for dryrun
if [[ ${dryrun} == true ]]; then
  echo "Dryrun requested, exiting script before applying changes!"
  exit 0
fi

# Replace
mysql ${dbparam} -Bse "UPDATE \`${dbname}\`.records SET content = replace(content, '${search}', '${replace}')"

# Increase serial of affected zones
for domainid in ${affecteddomains[*]}; do
  domain=$(mysql ${dbparam} -Bse "SELECT name FROM \`${dbname}\`.domains WHERE id = ${domainid}")
  pdnsutil increase-serial ${domain}
done

# Reload and rectify (all) zones
echo "Rectifying and reloading (all) zones"
pdnsutil rectify-all-zones
pdns_control reload

if [[ ${slaves} == true ]]; then
  echo "Notifying slave(s) about changes in affected domains"
  # Notify slaves
  for domainid in ${affecteddomains[*]}; do
    domain=$(mysql ${dbparam} -Bse "SELECT name FROM \`${dbname}\`.domains WHERE id = ${domainid}")
    pdns_control notify ${domain}
  done
fi

exit
