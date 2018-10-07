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
TEMPDIR="/tmp"

TIMESTAMP=$(date +%d-%m-%Y_%H-%M-%S)

#
# FUNCTIONS
#

# Function print help message
function PrintHelp() {
cat <<EOF
Zabbix backup script (Version 0.1)

Usage: zbackup [opts]

OPTIONS
-a <days>		Auto remove old backups after ? days (default: 10). 
-d <dir>		Path to backup
-h			Print help
-l <path>		Path to log file (default: /var/log/zabbix/zbackup.log) 	
-t <path>		Path to temp directory (default: /tmp) 	
-u <username> 		MySQL user
-p <pass>		MySQL password

EOF
}

# Function remove all temp folders created by this script
function ClearTemp() {
	if [[ -d $TEMPDIR ]]; then
		rm -rf $TEMPDIR/zbackup-* 2>>$OGFILE
	fi
}

if [[ $# -eq 0 ]]; then PrintHelp; exit 0; fi 

#
# PARSE OPTONS
#

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

# Create temp folder
if ! mkdir $TEMPDIR; then echo "${TIMESTAMP} ERROR: Can not create temp folder ${TEMPDIR}" >&2 >>$LOGFILE; exit 1; fi 
# Start backup
echo "Backup started."

if [[ -z "${BACKUPDIR}" ]]; then echo "ERROR: You must provide backup directory path. Use option -d <dir>." >&2 >>$LOGFILE exit 1; fi
