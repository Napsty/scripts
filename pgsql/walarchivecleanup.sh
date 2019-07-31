#!/usr/bin/env bash
#########################################################################
# Script:       walarchivecleanup.sh
# Purpose:      Clean up archived WAL logs on a PostgreSQL master server
# Authors:      Claudio Kuenzler www.claudiokuenzler.com (2017)
# 
# History:
# 2017-10-27 1.0 Create and publish script
# 2017-11-02 1.1 Use different find cmd to determine newest deletable file within range
# 2019-05-17 1.2 Ignore .ready and .backup files, set maxdepth
# 2019-07-31 1.3 Hint in documentation about -a parameter and keep age
#########################################################################
help="$0 (c) 2017,2019 Claudio Kuenzler
This script helps to clean up archived WAL logs on a PostgreSQL master server using the pg_archivecleanup command. 
Please note that WAL archiving currently only works on a master server (as of 9.6).
---------------------
Options:
  -p         Path to the archived WAL logs (e.g. /var/lib/postgresql/9.6/main/archive)
  -a         Age of archived logs to keep (in days), anything older will be deleted (Note: use '0' to delete WAL logs older than 24h)
  -f         Specify a certain archived WAL file, anything older than this file will be deleted
             Note: If you use -f, it will override -a parameter
  -c         Full path to pg_archivecleanup command (if not found in \$PATH)
  -d         Show debug information
  -n         Dry run (simulation only)
---------------------
Usage: $0 -p archivepath -a age (days) [-d debug] [-f archivefile] [-c path_to_pg_archivecleanup]
Example 1: $0 -p /var/lib/postgresql/9.6/main/archive -a 10
Example 2: $0 -p /var/lib/postgresql/9.6/main/archive -f 00000001000000010000001E
---------------------
Cronjob example: 00 03 * * * /root/scripts/walarchivecleanup.sh -p /var/lib/postgresql/9.6/main/archive -a 14" 
#########################################################################
# Check necessary commands are available
for cmd in find awk sort [
do
 if ! `which ${cmd} 1>/dev/null`
 then
 echo "UNKNOWN: ${cmd} does not exist, please check if command exists or PATH is correct"
 exit ${STATE_UNKNOWN}
 fi
done
#########################################################################
# Check for people who need help - arent we all nice ;-)
if [ "${1}" = "--help" -o "${#}" = "0" ];
       then
       echo -e "${help}";
       exit ${STATE_UNKNOWN};
fi
#########################################################################
# Get user-given variables
while getopts "p:a:f:c:dn" Input;
do
       case ${Input} in
       p)      archivepath=${OPTARG};;
       a)      age=${OPTARG};;
       f)      archivefile=${OPTARG};;
       c)      archivecleanup=${OPTARG};;
       d)      debug=true;;
       n)      dry=true;;
       *)      echo -e $help
               exit 1
               ;;
       esac
done
#########################################################################
# Did user obey to usage?
if [[ -z $archivepath ]]; then echo "Error: Missing archivepath"; exit 1; fi
if [[ -z $age ]] && [[ -z $archivefile ]]; then echo "Error: Either age (-a) or archivefile (-f) must be given"; exit 1; fi

# Check if archivepath exists
if ! [[ -d $archivepath ]]; then 
  echo "Error: archivepath not found"; exit 1
else
  cmd_path=$archivepath
fi

# Check if pg_archivecleanup is found
if [[ -n $archivecleanup ]]; then 
  if ! [[ -x $archivecleanup ]]; then 
    echo "Error: Command $archivecleanup not found or no permission to execute"; exit 1; 
  else
    cmd_command="$archivecleanup"
  fi
else 
  if ! `which pg_archivecleanup 1>/dev/null`; then echo "Error: Command pg_archivecleanup not found"; exit 1; fi
  cmd_command="pg_archivecleanup"
fi
#########################################################################
# Create command
if [[ $debug = true ]]; then cmd_debug="-d"; fi
if [[ $dry = true ]]; then cmd_dry="-n"; fi
if [[ -n $age ]] && [[ -z $archivefile ]]; then
  cmd_file="$(find ${archivepath}/ -maxdepth 1 -type f -not -name '*.ready' -not -name '*.backup' -mtime +${age} -printf "%C@ %f\n" |sort -n | tail -n 1 | awk '{print $NF}')"
else
  cmd_file="$archivefile"
fi

execute="$cmd_command $cmd_debug $cmd_dry $cmd_path $cmd_file"
#echo $execute

`$execute`

exit $? 

echo "Unknown Error - Should never reach this part"
exit 1
