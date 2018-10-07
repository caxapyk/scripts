#!/bin/bash

# 
# Archive all Zabbix files and grab data from MySQL using Percona XtraBackup.
#
# Alexander Sakharuk <saharuk.alexander@gmail.com>,  2018
# Licensed under MIT licence
#

#
# DEFAULTS
#
AUTOREMOVE=10
LOGFILE="/var/log/zabbix/zbackup.log"
DBUSER="zabbix"
DBPASS="zabbix"

function PrintHelp() {
cat <<EOF
Zabbix backup script (Version 0.1)

Usage: zbackup [opts]

OPTIONS
-a <days>		Auto remove old backups after ? days (default: 10). 
-d <dir>		Path to backup
-h			Print help
-l <path>		Path to log file (default: /var/log/zabbix/zbackup.log) 	
-u <username> 		MySQL user
-p <pass>		MySQL password

EOF
}

if [[ $# -eq 0 ]]; then PrintHelp; exit 0; fi 

# Parse options
while getopts "a:d:hl:t:u:p:" opt; do
	case $opt in
		a) AUTOREMOVE="${OPTARG}" ;;
		d) BACKUPDIR="${OPTARG}" ;;
		h) PrintHelp ;;
		l) LOGFILE="${OPTARG}" ;;
		t) TEMPDIR="${OPTARG}" ;;
		u) DBUSER="${OPTARG}" ;;
		p) DBPASS="${OPTARG}" ;;
	esac
done

# Validate input
if [[ -z "${BACKUPDIR}" ]]; then echo "ERROR: You must provide backup directory path. Use option -d <dir>." >&2 >>$LOGFILE exit 1; fi

# Create temp folder
if ! mkdir $TEMPDIR; then echo "ERROR: Can not create temp folder at ${TEMPDIR}" >&2 >>$LOGFILE; exit 1; fi 

# Start backup
echo "Backup started."

