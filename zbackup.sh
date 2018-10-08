#!/bin/bash

# 
# Full backup of Zabbix MySQL/MariaDB database (using Percona XtraBackup) and Zabbix files (using Rsync).
#
# Alexander Sakharuk <saharuk.alexander@gmail.com>,  2018
# Licensed under MIT licence
#

#
# DEFAULTS
#

AUTOREMOVE=10
LOG="/var/log/zbackup.log"
DBUSER="zabbix"
DBPASS="zabbix"
TEMPDIR="/tmp/zbackup"

TIMESTAMP=$(date +%d-%m-%Y_%H-%M-%S)
TARFILE="zbackup-${TIMESTAMP}.tar.gz"

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
-c			Clear temp. 
-d <path>		Backup directory
-h			Print help
-l <path>		Path to log file (default: /var/log/zbackup.log) 	
-t <path>		Temp directory with incremental backup (default: /tmp/zbackup) 	
-u <username> 		MySQL user
-p <pass>		MySQL password

EOF
exit 0;
}

# Function remove all temp folders created by this script
function DeleteTemp() {
	if [[ -d $TEMPDIR ]]; then
		rm -rf $TEMPDIR/* 2>>$LOG 
	fi
}

# Funtion prints fatal error and returns exit code.
function exitErr() {
	echo "${TIMESTAMP} ERROR: $1" >>$LOG
	echo -e "Zbackup failed. See logfile):" \
		"\ncat ${LOG}"
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
		d) BAKDIR="${OPTARG}"
		;;
		l) LOG="${OPTARG}"
		;;
		t) TEMPDIR="${OPTARG}"
		;;
		u) DBUSER="${OPTARG}"
		;;
		p) DBPASS="${OPTARG}"
		;;
		c) DeleteTemp && echo "Temp directory has been deleted."
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
echo "${TIMESTAMP} zbackup script started." > $LOG

# Delete temp
DeleteTemp;

# Check backup directory exists
if [[ ! -d "$BAKDIR" ]]; then
	exitErr "You must provide valid backup directory path. Use option -d <dir>."
fi

# Create temp folder structure
if ! mkdir -p $TEMPDIR \
	"${TEMPDIR}/var/lib/mysql" \
	"${TEMPDIR}/etc" \
	"${TEMPDIR}/usr/lib" \
	"${TEMPDIR}/usr/share"; 
then
	exitErr "Can't create temp directory: ${TEMPDIR}"
fi 

#
# BACKUP
#

echo "`date +%d-%m-%Y_%H:%M:%S` Backup started..." | tee -a $LOG

# Step 01: backup DB with Percona XtraBackup
if [[ -x "$(command -v xtrabackup)" ]]; then
	echo "(1/4) MySQL backup..." | tee -a $LOG

	service zabbix-server stop 2>>$LOG

	xtrabackup --backup \
		--user="${DBUSER}" \
		--password="${DBPASS}" \
		--no-timestamp \
		--target-dir="${TEMPDIR}/var/lib/mysql" &>>$LOG
	xtrabackup --prepare \
		--apply-log-only \
		--target-dir="${TEMPDIR}/var/lib/mysql" &>>$LOG

	service zabbix-server start 2>>$LOG

else
	exitErr "'extrabackup' utility not found."
fi

# Step 02: sync zabbix files
echo "(2/4) Copying Zabbix files..." | tee -a $LOG
rsync -avz /etc/zabbix "${TEMPDIR}/etc/" &>>$LOG
rsync -avz /usr/lib/zabbix "${TEMPDIR}/usr/lib/" &>>$LOG
rsync -avz /usr/share/zabbix "${TEMPDIR}/usr/share/" &>>$LOG

# Step 03: archiving
echo "(3/4) Archiving..." | tee -a $LOG
if [[ -w $BAKDIR ]]; then
	tar -czvf "${BAKDIR}/${TARFILE}" -C $TEMPDIR . &>>$LOG
else
	exitErr "Can't archive data. No access.";
fi

# Step 04: remove old backups
echo "(4/4) Remove old backups..." | tee -a $LOG
find $BAKDIR -mmin +$AUTOREMOVE -type f -delete -print &>>$LOG

# Finish
echo -e "`date +%d-%m-%Y_%H:%M:%S` Backup has been created." \
	"\n`stat "${BAKDIR}/${TARFILE}"`"| tee -a $LOG
