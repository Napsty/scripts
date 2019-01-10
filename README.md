# scripts
This is a collection of scripts which do some pretty handy work. 
Some of them are created by myself, some were found all over. 

This repo is intended to collect these scripts together at one place, so I don't have to search them for each new system. 
Feel free to use it, too. 

Description of some scripts (list may be incomplete)
--

```
couchdb/compact_couchdb.sh -> CouchDB maintenance script to compact databases and views
linux/bin2hex.pl -> (Attempt to) Convert binary scripts to cleartext
linux/bootinfoscript.sh -> Collecting data about OS's drive setup, including bootloader, partitions, etc
linux/conv.pl -> (Attempt to) Convert binary scripts to cleartext
linux/mb2md.pl -> Converts Mbox mailboxes to Maildir format (note: package mb2md)
linux/swapusage.sh -> Collecting data for swap usage and prints which procs use most swap
mongodb/logrotate-mongodb.sh -> Force MongoDB to rotate the MongoDB logfile (without downtime)
pgsql/walarchivecleanup.sh -> Cleanup old PostgreSQL WAL logs according to age
security/check_filesystem.sh -> Scan the filesystem for the CryptoPHP backdoor
security/findbot.pl -> Trying to identify suspicious (php) files
security/joomscan.pl -> Joomla Vulnerability Scanner
security/testssl.sh -> SSL/TLS security testing, including insecure ciphers and vulnerabilities
webserver/delapacheuserfiles-interactive.php -> Delete files (in browser) which were created by webserver user (interactive)
webserver/delapacheuserfiles-without-asking.php -> Delete files (in browser) which were created by webserver user (does not ask, just deletes)
zoneminder/zoneminder-event-cleanup.sh -> Cleanup old Zoneminder recordings/events but keep archived ones
```
