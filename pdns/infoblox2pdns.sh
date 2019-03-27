#!/bin/bash
###############################################################
# Script:       infoblox2pdns.sh
# Author:       Claudio Kuenzler (www.claudiokuenzler.com)
# Description:  infoblox2pdns.sh is a script which helps you
# to migrate your DNS zones from an Infoblox appliance to 
# PowerDNS authoritative server using the exported records 
# from Infloblox saved as a CSV file (Export visible data). 
# This script _may_ in general work with CSV exported zones, 
# as long as the CSV format matches the one from Infoblox. 
# See an example zone export further down after Usage.
###############################################################
# Changelog:    
# 1.0 First public version (published on March 26 2019)
# 1.1 Set replication type to MASTER
# 1.2 Added possibility to import comments, too (using -c dbname)
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
# Usage: infoblox2pdns.sh -f /path/to/file.csv -d domain [-n "Nameservers"] [-v] [-s]
# Usage Example: ./infoblox2pdns.sh -f /tmp/ResourceRecords.csv -d example.net
###############################################################
# An Infoblox zone export in CSV format will look the following way:
#"Name","Type","Data","Comment","Site"
#"","SOA Record","ns1.example.com dnsadmin@example.com 12 3600 3600 2592000 900","Auto-created by Add Zone",""
#"","NS Record","ns1.example.com","Auto-created by Add Zone",""
#"","NS Record","ns2.example.com","Auto-created by Add Zone",""
#"","MX Record","5 mail.example.com","Comment",""
#"","A Record","1.1.1.1","Comment",""
#"www","CNAME Record","example.com","Comment",""
#"","TXT Record","google-site-verification=Sh6y_XCtCzzQMED09_pKSc9rh1O3n6TKJ-Bf0o8XHE4","Comment",""
#"_sip._tls","SRV Record","0 0 443 sip.example.com","",""
###############################################################
# Version
version=1.2

# Fixed variables / defaults
timestamp=$(date +%s)
simulate=0
###############################################################
# Help 
help="$0 $version (c) 2019 Claudio Kuenzler\n
Usage: $0 -f /path/to/file.csv -d domain.com [-n 'ns1.example.com ns2.example.com ns3.example.com']\n
Options:
-f Path to the csv file which was exported from Infoblox
-d Domain Name (example.com)
-n List of nameservers separated by whitespace to overwrite the NS records found from the CSV file (-n 'ns1.example.com ns2.example.com ns3.example.com'). Note: The first nameserver will be handled as primary nameserver.
-c Name of MySQL database if you want to import the comments from the CSV as well. '-c powerdns' would mean powerdns.comments table. This will use the MySQL credentials of your current Shell user (see ~./my.cnf).
-v Verbose (Show all found records and all pdns commands)
-s Simulate (Does nothing in PowerDNS, just shows what the script would do in verbose)
-h Show help\n
Requirements: csvtool\n"

# Check for people who need help - aren't we all nice ;-)
if [ "${1}" = "--help" ] || [ "${#}" = "0" ];
       then
       echo -e "${help}";
       exit 1;
fi
###############################################################
# Get user-given variables
while getopts "d:f:n:c:vhs" Input;
do
       case ${Input} in
       d)      domain=${OPTARG};;
       f)      csvfile=${OPTARG};;
       n)      nameservers=${OPTARG};;
       c)      commentdb=${OPTARG};;
       v)      verbose=1;;
       s)      simulate=1;;
       h)      echo -e "${help}"; exit 1;;
       *)      echo -e "${help}"; exit 1;;
       esac
done
###############################################################
# Does the input file really exist?
if ! [[ -r $csvfile ]]; then echo "ERROR: Cannot read $1"; exit 1; fi

# Was the domain added in command line?
if [[ -z $domain ]]; then echo "ERROR: Domain not given"; exit 1; fi

# Check for additional required programs
for cmd in csvtool
do
 if ! `which ${cmd} 1>/dev/null`
 then
 echo "ERROR: ${cmd} does not exist, please check if command exists and PATH is correct"
 exit ${STATE_UNKNOWN}
 fi
done

# Does the zone already exist?
pdnsutil list-zone $domain 1>/dev/null
if [[ $? -eq 0 ]]; then echo "ERROR: Domain/Zone already exists"; exit 1; fi
###############################################################
# Use csvtool to sanitize and clean input
zonerecords=$(csvtool col 1-4 $csvfile)

# Put the mass records into arrays
if [[ -z $nameservers ]]; then 
  # No new DNS nameservers given, we use the same from the exported CSV
  declare -a ns_records=( $(echo "$zonerecords" | awk 'BEGIN {FS=","} /NS Record/ { print $3 }') )
else
  # We overwrite the previous DNS nameservers with the ones defined with -n
  declare -a ns_records=( $(echo "$nameservers") )
fi
declare -a a_records=( $(echo "$zonerecords" | egrep -w "A Record" | awk 'BEGIN {FS=","} { print $1"=>"$3 }') ) 
declare -a a_comments=( $(echo "$zonerecords" | egrep -w "A Record" | awk 'BEGIN {FS=","} { print $1"=>"$4 }' | sed "s/ /_/g") ) # Replace whitespaces in comments
declare -a aaaa_records=( $(echo "$zonerecords" | egrep -w "AAAA Record" | awk 'BEGIN {FS=","} { print $1"=>"$3 }') ) 
declare -a aaaa_comments=( $(echo "$zonerecords" | egrep -w "AAAA Record" | awk 'BEGIN {FS=","} { print $1"=>"$4 }' | sed "s/ /_/g") ) # Replace whitespaces in comments
declare -a cname_records=( $(echo "$zonerecords" | awk 'BEGIN {FS=","} /CNAME Record/ { print $1"=>"$3 }') ) 
declare -a cname_comments=( $(echo "$zonerecords" | awk 'BEGIN {FS=","} /CNAME Record/ { print $1"=>"$4 }' | sed "s/ /_/g") )  # Replace whitespaces in comments
declare -a mx_records=( $(echo "$zonerecords" | awk 'BEGIN {FS=","} /MX Record/ { print $1"=>"$3 }' | sed "s/ /;/g") ) # Replace whitspaces between Priority and Target
declare -a mx_comments=( $(echo "$zonerecords" | awk 'BEGIN {FS=","} /MX Record/ { print $1"=>"$4 }' | sed "s/ /_/g") )  # Replace whitespaces in comments
declare -a txt_records=( $(echo "$zonerecords" | awk 'BEGIN {FS=","} /TXT Record/ { print $1"=>"$3 }' | sed "s/ /;/g") ) # Temporary replace whitespaces in value 
declare -a txt_comments=( $(echo "$zonerecords" | awk 'BEGIN {FS=","} /TXT Record/ { print $1"=>"$4 }' | sed "s/ /_/g") )  # Replace whitespaces in comments
declare -a srv_records=( $(echo "$zonerecords" | awk 'BEGIN {FS=","} /SRV Record/ { print $1"=>"$3 }' | sed "s/ /;/g") )
declare -a srv_comments=( $(echo "$zonerecords" | awk 'BEGIN {FS=","} /SRV Record/ { print $1"=>"$4 }' | sed "s/ /_/g") )  # Replace whitespaces in comments

# SOA is a single record
soa_full=$(echo "$zonerecords" | awk 'BEGIN {FS=","} /SOA Record/ { print $3 }')
soa_primary_dns=$(echo ${ns_records[*]} | awk -F" " '{ print $1 }') 
soa_contact=$(echo $soa_full | awk -F" " '{ print $2"." }') 
soa_serial=$(echo $soa_full | awk -F" " '{ print $3 }')
soa_refresh=$(echo $soa_full | awk -F" " '{ print $4 }')
soa_retry=$(echo $soa_full | awk -F" " '{ print $5 }')
soa_expire=$(echo $soa_full | awk -F" " '{ print $6 }')
soa_negative_ttl=$(echo $soa_full | awk -F" " '{ print $7 }')

if [[ $verbose -eq 1 || $simulate -eq 1 ]]; then
echo "Original SOA: $soa_full"
echo "Primary DNS: $soa_primary_dns"
echo "Original Contact: $soa_contact"
echo "Original Serial: $soa_serial"
echo "Original Refresh: $soa_refresh"
echo "Original Retry: $soa_retry"
echo "Original Expire: $soa_expire"
echo "Original Negative TTL: $soa_negative_ttl"
echo "Found the following NS records: ${ns_records[*]}"
echo "Found the following A records: ${a_records[*]}"
echo "Found the following A comments: ${a_comments[*]}"
echo "Found the following AAAA records: ${aaaa_records[*]}"
echo "Found the following AAAA comments: ${aaaa_comments[*]}"
echo "Found the following CNAME records: ${cname_records[*]}"
echo "Found the following CNAME comments: ${cname_comments[*]}"
echo "Found the following MX records: ${mx_records[*]}"
echo "Found the following MX comments: ${mx_comments[*]}"
echo "Found the following TXT records: ${txt_records[*]}"
echo "Found the following TXT comments: ${txt_comments[*]}"
echo "Found the following SRV records: ${srv_records[*]}"
echo "Found the following SRV comments: ${srv_comments[*]}"
fi

# Create domain
if [[ $verbose -eq 1 || $simulate -eq 1 ]]; then echo "pdnsutil create-zone $domain $soa_primary_dns"; fi
if [[ $simulate -eq 0 ]]; then pdnsutil create-zone $domain $soa_primary_dns; fi

# Get domain ID from MySQL database defind by -c parameter
if [[ -n $commentdb ]]; then domainid=$(mysql -Bse "select id from ${commentdb}.domains WHERE name = '$domain'"); fi


# Add SOA record 
# SOA entry is already created by create-zone command and there is currently no delete-record command to replace it. So we keep this one idle here.
#if [[ $verbose -eq 1 || $simulate -eq 1 ]]; then echo "pdnsutil add-record $domain @ SOA '$soa_primary_dns $soa_contact $soa_serial $soa_refresh $soa_retry $soa_expire $soa_negative_ttl'"; fi
#if [[ $simulate -eq 0 ]]; then pdnsutil add-record $domain @ SOA "$soa_primary_dns $soa_contact $soa_serial $soa_refresh $soa_retry $soa_expire $soa_negative_ttl"; fi
# can't touch this! see https://github.com/PowerDNS/pdns/issues/6031 and https://github.com/PowerDNS/pdns/pull/3169/files

# Add NS records
nserr=0
for nameserver in $(echo ${ns_records[*]}); do
  if [[ $nameserver = $soa_primary_dns ]]; then echo "Skipping primary DNS, it was already added by create-zone"; continue; fi
  if [[ $verbose -eq 1 || $simulate -eq 1 ]]; then echo "pdnsutil add-record $domain @ NS $nameserver"; fi
  if [[ $simulate -eq 0 ]]; then pdnsutil add-record $domain @ NS $nameserver; [[ $? -gt 0 ]] && let nserr++; fi
done

# Each A record is in this format: "entry=>value". If entry is empty, this should be translated to @.
aerr=0
for arecord in $(echo ${a_records[*]}); do
  entry=$(echo $arecord | awk -F'=>' '{print $1}')
  value=$(echo $arecord | awk -F'=>' '{print $2}')
  if [[ "$entry" = "" ]]; then entry="@"; dbfieldname="$domain"; else dbfieldname="${entry}.${domain}"; fi
  if [[ $verbose -eq 1 || $simulate -eq 1 ]]; then echo "pdnsutil add-record $domain '$entry' A '$value'"; fi
  if [[ $simulate -eq 0 ]]; then pdnsutil add-record $domain "$entry" A "$value"; [[ $? -gt 0 ]] && let aerr++; fi
done

# Each A comment is in this format: "entry=>comment". If entry is empty, this should be translated to @.
for acomment in $(echo ${a_comments[*]}); do 
  entry=$(echo $acomment | awk -F'=>' '{print $1}')
  comment=$(echo "$acomment" | awk -F'=>' '{print $2}')
  if [[ "$entry" = "" ]]; then entry="@"; dbfieldname="$domain"; else dbfieldname="${entry}.${domain}"; fi
  if [[ $verbose -eq 1 || $simulate -eq 1 ]]; then
    echo "mysql -e \"INSERT INTO ${commentdb}.comments (domain_id, name, type, modified_at, comment) VALUES ('$domainid', '$dbfieldname', 'A', '$timestamp', '$comment')\""
  fi
  if [[ $simulate -eq 0 ]]; then
    if [[ -n $commentdb && $domainid -gt 0 && -n $comment ]]; then
      mysql -e "INSERT INTO ${commentdb}.comments (domain_id, name, type, modified_at, comment) VALUES ('$domainid', '$dbfieldname', 'A', '$timestamp', '$comment')"
    fi
  fi
done


# Each AAAA record is in this format: "entry=>value=>comment". If entry is empty, this should be translated to @.
aaaaerr=0
for aaaarecord in $(echo ${aaaa_records[*]}); do
  entry=$(echo $aaaarecord | awk -F'=>' '{print $1}')
  value=$(echo $aaaarecord | awk -F'=>' '{print $2}')
  if [[ "$entry" = "" ]]; then entry="@"; dbfieldname="$domain"; else dbfieldname="${entry}.${domain}"; fi
  if [[ $verbose -eq 1 || $simulate -eq 1 ]]; then echo "pdnsutil add-record $domain '$entry' AAAA '$value'"; fi
  if [[ $simulate -eq 0 ]]; then pdnsutil add-record $domain "$entry" AAAA "$value"; [[ $? -gt 0 ]] && let aaaaerr++; fi
done

# Each AAAA comment is in this format: "entry=>comment". If entry is empty, this should be translated to @.
for aaaacomment in $(echo ${aaaa_comments[*]}); do 
  entry=$(echo $aaaacomment | awk -F'=>' '{print $1}')
  comment=$(echo "$aaaacomment" | awk -F'=>' '{print $2}')
  if [[ "$entry" = "" ]]; then entry="@"; dbfieldname="$domain"; else dbfieldname="${entry}.${domain}"; fi
  if [[ $verbose -eq 1 || $simulate -eq 1 ]]; then
    echo "mysql -e \"INSERT INTO ${commentdb}.comments (domain_id, name, type, modified_at, comment) VALUES ('$domainid', '$dbfieldname', 'AAAA', '$timestamp', '$comment')\""
  fi
  if [[ $simulate -eq 0 ]]; then
    if [[ -n $commentdb && $domainid -gt 0 && -n $comment ]]; then
      mysql -e "INSERT INTO ${commentdb}.comments (domain_id, name, type, modified_at, comment) VALUES ('$domainid', '$dbfieldname', 'AAAA', '$timestamp', '$comment')"
    fi
  fi
done

# Each CNAME record is in this format: "entry=>value". 
cnameerr=0
for cnamerecord in $(echo "${cname_records[*]}"); do
  entry=$(echo $cnamerecord | awk -F'=>' '{print $1}')
  value=$(echo $cnamerecord | awk -F'=>' '{print $2"."}') #Add a trailing dot
  if [[ $verbose -eq 1 || $simulate -eq 1 ]]; then echo "pdnsutil add-record $domain '$entry' CNAME '$value'"; fi
  if [[ $simulate -eq 0 ]]; then pdnsutil add-record $domain "$entry" CNAME "$value"; [[ $? -gt 0 ]] && let cnameerr++; fi
done

# Each CNAME comment is in this format: "entry=>comment"
for cnamecomment in $(echo ${cname_comments[*]}); do 
  entry=$(echo $cnamecomment | awk -F'=>' '{print $1}')
  comment=$(echo "$cnamecomment" | awk -F'=>' '{print $2}')
  if [[ $verbose -eq 1 || $simulate -eq 1 ]]; then
    echo "mysql -e \"INSERT INTO ${commentdb}.comments (domain_id, name, type, modified_at, comment) VALUES ('$domainid', '${entry}.${domain}', 'CNAME', '$timestamp', '$comment')\""
  fi
  if [[ $simulate -eq 0 ]]; then
    if [[ -n $commentdb && $domainid -gt 0 && -n $comment ]]; then
      mysql -e "INSERT INTO ${commentdb}.comments (domain_id, name, type, modified_at, comment) VALUES ('$domainid', '${entry}.${domain}', 'CNAME', '$timestamp', '$comment')"
    fi
  fi
done


# Each MX record is in this format: "entry=>priority;mailserver". 
mxerr=0
for mxrecord in $(echo ${mx_records[*]}); do
  entry=$(echo $mxrecord | awk -F'=>' '{print $1}')
  if [[ "$entry" = "" ]]; then entry="@"; dbfieldname="$domain"; else dbfieldname="${entry}.${domain}"; fi
  priority=$(echo $mxrecord | awk -F'=>' '{print $2}' | awk -F';' '{print $1}' ) 
  mailserver=$(echo $mxrecord | awk -F'=>' '{print $2}' | awk -F';' '{print $2"."}' ) #Add a trailing dot
  if [[ $verbose -eq 1 || $simulate -eq 1 ]]; then echo "pdnsutil add-record $domain $entry MX '$priority $mailserver'"; fi
  if [[ $simulate -eq 0 ]]; then pdnsutil add-record $domain $entry MX "$priority $mailserver"; [[ $? -gt 0 ]] && let mxerr++; fi
done

# Each MX comment is in this format: "entry=>comment". If entry is empty, this should be translated to @.
for mxcomment in $(echo ${mx_comments[*]}); do 
  entry=$(echo $mxcomment | awk -F'=>' '{print $1}')
  comment=$(echo "$mxcomment" | awk -F'=>' '{print $2}')
  if [[ "$entry" = "" ]]; then entry="@"; dbfieldname="$domain"; else dbfieldname="${entry}.${domain}"; fi
  if [[ $verbose -eq 1 || $simulate -eq 1 ]]; then
    echo "mysql -e \"INSERT INTO ${commentdb}.comments (domain_id, name, type, modified_at, comment) VALUES ('$domainid', '$dbfieldname', 'MX', '$timestamp', '$comment')\""
  fi
  if [[ $simulate -eq 0 ]]; then
    if [[ -n $commentdb && $domainid -gt 0 && -n $comment ]]; then
      mysql -e "INSERT INTO ${commentdb}.comments (domain_id, name, type, modified_at, comment) VALUES ('$domainid', '$dbfieldname', 'MX', '$timestamp', '$comment')"
    fi
  fi
done


# Each TXT record is in this format: "entry=>value". If entry is empty, this should be translated to @.
txterr=0
for txtrecord in $(echo ${txt_records[*]}); do
  entry=$(echo $txtrecord | awk -F'=>' '{print $1}')
  value=$(echo $txtrecord | sed "s/;/ /g" | awk -F'=>' '{print "\""$2"\""}' | sed 's/"\{2,\}"/"/g') # Make sure we use doublequotes only once
  if [[ "$entry" = "" ]]; then entry="@"; dbfieldname="$domain"; else dbfieldname="${entry}.${domain}"; fi
  if [[ $verbose -eq 1 || $simulate -eq 1 ]]; then echo "pdnsutil add-record $domain '$entry' TXT '$value'"; fi
  if [[ $simulate -eq 0 ]]; then pdnsutil add-record $domain "$entry" TXT "$value"; [[ $? -gt 0 ]] && let txterr++; fi
done

# Each TXT comment is in this format: "entry=>comment". If entry is empty, this should be translated to @.
for txtcomment in $(echo ${txt_comments[*]}); do 
  entry=$(echo $txtcomment | awk -F'=>' '{print $1}')
  comment=$(echo "$txtcomment" | awk -F'=>' '{print $2}')
  if [[ "$entry" = "" ]]; then entry="@"; dbfieldname="$domain"; else dbfieldname="${entry}.${domain}"; fi
  if [[ $verbose -eq 1 || $simulate -eq 1 ]]; then
    echo "mysql -e \"INSERT INTO ${commentdb}.comments (domain_id, name, type, modified_at, comment) VALUES ('$domainid', '$dbfieldname', 'TXT', '$timestamp', '$comment')\""
  fi
  if [[ $simulate -eq 0 ]]; then
    if [[ -n $commentdb && $domainid -gt 0 && -n $comment ]]; then
      mysql -e "INSERT INTO ${commentdb}.comments (domain_id, name, type, modified_at, comment) VALUES ('$domainid', '$dbfieldname', 'TXT', '$timestamp', '$comment')"
    fi
  fi
done


# Each SRV record is in this format: "entry=>priority;weight;port;target". If entry is empty, this should be translated to @.
srverr=0
for srvrecord in $(echo ${srv_records[*]}); do
  entry=$(echo $srvrecord | awk -F'=>' '{print $1}')
  if [[ "$entry" = "" ]]; then entry="@"; dbfieldname="$domain"; else dbfieldname="${entry}.${domain}"; fi
  priority=$(echo $srvrecord | awk -F'=>' '{print $2}' | awk -F';' '{print $1}' ) 
  weight=$(echo $srvrecord | awk -F'=>' '{print $2}' | awk -F';' '{print $2}' ) 
  port=$(echo $srvrecord | awk -F'=>' '{print $2}' | awk -F';' '{print $3}' ) 
  target=$(echo $srvrecord | awk -F'=>' '{print $2}' | awk -F';' '{print $4"."}' ) #Add a trailing dot
  if [[ $verbose -eq 1 || $simulate -eq 1 ]]; then echo "pdnsutil add-record $domain $entry SRV $priority $weight $port $target"; fi
  if [[ $simulate -eq 0 ]]; then pdnsutil add-record $domain $entry SRV "$priority $weight $port $target"; [[ $? -gt 0 ]] && let srverr++; fi
done

# Each SRV comment is in this format: "entry=>comment". If entry is empty, this should be translated to @.
for srvcomment in $(echo ${srv_comments[*]}); do 
  entry=$(echo $srvcomment | awk -F'=>' '{print $1}')
  comment=$(echo "$srvcomment" | awk -F'=>' '{print $2}')
  if [[ "$entry" = "" ]]; then entry="@"; dbfieldname="$domain"; else dbfieldname="${entry}.${domain}"; fi
  if [[ $verbose -eq 1 || $simulate -eq 1 ]]; then
    echo "mysql -e \"INSERT INTO ${commentdb}.comments (domain_id, name, type, modified_at, comment) VALUES ('$domainid', '$dbfieldname', 'SRV', '$timestamp', '$comment')\""
  fi
  if [[ $simulate -eq 0 ]]; then
    if [[ -n $commentdb && $domainid -gt 0 && -n $comment ]]; then
      mysql -e "INSERT INTO ${commentdb}.comments (domain_id, name, type, modified_at, comment) VALUES ('$domainid', '$dbfieldname', 'SRV', '$timestamp', '$comment')"
    fi
  fi
done

# Set replication type to master, Increase serial number for zone, reload pdns and send notifies to slaves 
if [[ $verbose -eq 1 || $simulate -eq 1 ]]; then echo "pdnsutil set-kind $domain MASTER"; fi
if [[ $simulate -eq 0 ]]; then pdnsutil set-kind $domain MASTER; fi
if [[ $verbose -eq 1 || $simulate -eq 1 ]]; then echo "pdnsutil increase-serial $domain"; fi
if [[ $simulate -eq 0 ]]; then pdnsutil increase-serial $domain; fi
if [[ $verbose -eq 1 || $simulate -eq 1 ]]; then echo "pdns_control reload"; fi
if [[ $simulate -eq 0 ]]; then pdns_control reload; fi
if [[ $verbose -eq 1 || $simulate -eq 1 ]]; then echo "pdns_control notify $domain"; fi
if [[ $simulate -eq 0 ]]; then pdns_control notify $domain; fi

# Show summary
echo "----------- Summary -----------"
echo "Added ${#ns_records[*]} NS records - $nserr failed"
echo "Added ${#a_records[*]} A records - $aerr failed"
echo "Added ${#aaaa_records[*]} AAAA records - $aaaaerr failed"
echo "Added ${#cname_records[*]} CNAME records - $cnameerr failed"
echo "Added ${#mx_records[*]} MX records - $mxerr failed"
echo "Added ${#txt_records[*]} TXT records - $txterr failed"
echo "Added ${#srv_records[*]} SRV records - $srverr failed"

# DNS Zone Check
if [[ $simulate -eq 0 ]]; then pdnsutil check-zone $domain; fi
