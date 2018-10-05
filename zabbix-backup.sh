#!/bin/bash

# 
# Archive all Zabbix files and grab data from MySQL using Percona XtraBackup.
# Alexander Sakharuk <saharuk.alexander@gmail.com> 2018
# MIT licence
#

function PrintHelp() {
cat <<EOF
Zabbix backup script.  

Usage: zabbix-backup [opts]

OPTIONS
-a <days>		Auto remove old backups after ? days (default: 7). 
-d <dir>		Path to backup
-h			Print help
-u <username> 		MySQL user
-p <pass>		MySQL password
EOF
}

if [[ $# -eq 0 ]]; then PrintHelp; exit 0; fi 

# Parse options
while getopts "a:d:hu:p:" opt; do
	case $opt in
		a) AUTOREMOVE="${OPTARG}" ;;
		d) BACKUPDIR="${OPTARG}" ;;
		h) PrintHelp ;;
		u) LOGFILE="${OPTARG}" ;;
		u) DBUSER="${OPTARG}" ;;
		p) DBPASS="${OPTARG}" ;;
	esac
done

# Validate input
if [[ -z "${BACKUPDIR}" ]]; then echo "ERROR: You must provide backup directory path. Use option -d <dir>." >&2; exit 1; fi
if [[ -z "${DBUSER}" ]]; then echo "ERROR: You must provide username to connect to the database. Use option -u <username>)." >&2; exit 1; fi
if [[ -z "${DBPASS}" ]]; then echo "ERROR: You must provide password to connect to the database. Use option -p <pass>)." >&2; exit 1; fi

# Set defaults

