#!/bin/bash

# 
# Incremental backup of Zabbix MySQL/MariaDB database (using Percona XtraBackup) and Zabbix files (using Rsync).
#
# Alexander Sakharuk <saharuk.alexander@gmail.com>,  2018
# Licensed under MIT licence
#

#
# DEFAULTS
#

AUTOREMOVE=10
LOGFILE="/var/log/zbackup.log"
DBUSER="zabbix"
DBPASS="zabbix"
TEMPDIR="/tmp/zbackup"

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
-l <path>		Path to log file (default: /var/log/zbackup.log) 	
-t <path>		Temp directory with incremental backup (default: /tmp/zbackup) 	
-u <username> 		MySQL user
-p <pass>		MySQL password

EOF
exit 0;
}

# Function remove all temp folders created by this script
function ClearTemp() {
	if [[ -d $TEMPDIR ]]; then
		rm -rf $TEMPDIR 2>>$OGFILE
	fi
}

# Funtion prints fatal error and returns exit code.
function exitErr() {
	echo "${TIMESTAMP} ERROR: $1" >&2 >>$LOGFILE
	echo -e "Zbackup failed. See logfile (${LOGFILE}):"
	cat $LOGFILE
        exit 1
}

if [[ $# -eq 0 ]]; then PrintHelp; exit 0; fi 

#
# PARSE OPTONS
#

while getopts ":a:d:hl:t:u:p:" opt; do
	case $opt in
		a) AUTOREMOVE="${OPTARG}"
		;;
		d) BACKUPDIR="${OPTARG}"
		;;
		l) LOGFILE="${OPTARG}"
		;;
		t) TEMPDIR="${OPTARG}"
		;;
		u) DBUSER="${OPTARG}"
		;;
		p) DBPASS="${OPTARG}"
		;;
		h) PrintHelp
		;;
		/?) echo "Invalid option ${OPTARG}" >&2
		;;
	esac
done

#
# PRE-ACTIONS
#

# Clean log file
echo "${TIMESTAMP} zbackup script started." > $LOGFILE

# Check backup directory exists
if [[ ! -d "$BACKUPDIR" ]]; then
	exitErr "You must provide valid backup directory path. Use option -d <dir>."
fi

# Create temp folder structure
if ! mkdir -p $TEMPDIR \
	"${TEMPDIR}/var/lib/mysql" \
	"${TEMPDIR}/etc/zabbix" \
	"${TEMPDIR}/usr/lib/zabbix" \
	"${TEMPDIR}/usr/share/zabbix"; 
then
	exitErr "Can't create temp directory: ${TEMPDIR}"
fi 

#
# BACKUP
#

echo "Backup started..."

# Step 01: backup DB with Percona XtraBackup
if [[ -x "$(command -v extrabackup)" ]]; then
	
	xtrabackup --backup \
		--user="${DBUSER}" \
		--password="${DBPASS}" \
		--no-timestamp \
		--target-dir="${TEMPDIR}/var/lib/mysql"\
		--datadir=/var/lib/mysql/ 1>&2 >>$LOGFILE	
	xtrabackup --prepare \
		--apply-log-only \
		--target-dir="${TEMPDIR}" 1>&2 >>$LOGFILE
else
	exitErr "'extrabackup' utility not found."
fi

# Step 02: sync zabbix files
rsync -avz /etc/zabbix/ "${TEMPDIR}/etc/zabbix"
rsync -avz /usr/lib/zabbix "${TEMPDIR}/usr/lib/zabbix"
rsync -avz /usr/share/zabbix "${TEMPDIR}/usr/share/zabbix"

# Step 03: archiving
tar -czvf "${BACKUPDIR}/zbackup-${TIMESTAMP}.tar.gz" -C $TEMPDIR . 1>&2 >>$LOGFILE
