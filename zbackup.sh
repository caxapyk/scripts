#!/bin/bash

# 
# Full backup of Zabbix MySQL/MariaDB database (using Percona XtraBackup) and Zabbix files (using Rsync).
#
# Alexander Sakharuk <saharuk.alexander@gmail.com>,  2018
# Licensed under MIT licence
#
# Examples
#
# # Make backup to current directory
# zbackup -d . -u <dbusername> -p <dbp@s$w0rd>
# # Make backup to /backup with 'zabbix:zabbix' credentials
# zbackup -d /backup
# # Add zbackup to crontab. Run from root required. sudo crontab -e
# * * * * * /<path to zbackup>/zbackup.sh -d <path> -u <dbusername> -p <dbp@ssw0rd>
#

#
# DEFAULTS
#

AUTOREMOVE=10
DBUSER="zabbix"
DBPASS="zabbix"
TEMPDIR="/tmp/zbackup"
LOGF="/var/log/zbackup.log"

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
-d <path>		Backup directory
-h			Print help
-t <path>		Temp directory (default: /tmp/zbackup) 	
-u <username> 		MySQL user
-p <pass>		MySQL password

EOF
exit 0;
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
		t) TEMPDIR="${OPTARG}"
		;;
		u) DBUSER="${OPTARG}"
		;;
		p) DBPASS="${OPTARG}"
		;;
		h) PrintHelp
		;;
		/?) echo "Invalid option ${OPTARG}" >>$LOGF
		;;
	esac
done

#
# PRE-ACTIONS
#

# Check Percona XtraBackup installed
if [[ ! -x "$(command -v xtrabackup)" ]]; then 
	echo "ERROR: 'extrabackup' utility not found." >>$LOGF
	printf "\n Go to https://www.percona.com/doc/percona-xtrabackup/LATEST/installation.html"
	exit 1
fi

# Remove temp
if [[ -d $TEMPDIR ]]; then
	rm -rf "${TEMPDIR}" 2>>$LOGF
	if [ $? -ne 0 ]; then echo "ERROR while trying to remove temp"; >>$LOGF exit 1; fi
fi

# Check backup directory exists
if [[ ! -d "$BAKDIR" ]]; then
       echo "ERROR: you must provide valid backup directory path. Use option -d <dir>." >>$LOGF
       exit 1
fi

# Create temp folder structure
mkdir -p "${TEMPDIR}" \
	"${TEMPDIR}/var/lib/mysql" \
	"${TEMPDIR}/etc" \
	"${TEMPDIR}/usr/lib" \
	"${TEMPDIR}/usr/share" 2>>$LOGF

if [ $? -ne 0 ]; then echo "ERROR while trying to create temp directory: ${TEMPDIR}" >>$LOGF; exit 1; fi

#
# BACKUP
#

# Step 01: backup DB with Percona XtraBackup
echo "(1/4) MySQL backup" | tee -a "${LOGF}"

# Make a backup and place it in xtrabackup --target-dir
xtrabackup --backup \
	--user="${DBUSER}" \
	--password="${DBPASS}" \
	--no-timestamp \
	--target-dir="${TEMPDIR}/var/lib/mysql" &>>$LOGF

if [ $? -ne 0 ]; then echo "ERROR: exrabackup returned the error code. Database backup failed." >>$LOGF; exit 1; fi

# Makes xtrabackup perform recovery on a backup so that it is ready to use
xtrabackup --prepare \
	--apply-log-only \
	--target-dir="${TEMPDIR}/var/lib/mysql" &>>$LOGF

if [ $? -ne 0 ]; then echo "ERROR: exrabackup returned error code. Database preparation failed." >>$LOGF; exit 1; fi

# Step 02: sync zabbix files
echo "(2/4) Copying Zabbix files" | tee -a "${LOGF}"

rsync -avz /etc/zabbix "${TEMPDIR}/etc/" &>>$LOGF &&
rsync -avz /usr/lib/zabbix "${TEMPDIR}/usr/lib/" &>>$LOGF &&
rsync -avz /usr/share/zabbix "${TEMPDIR}/usr/share/" &>>$LOGF

if [ $? -ne 0 ]; then echo "ERROR while trying to synchronize Zabbix files:" >>$LOGF; exit 1; fi

# Step 03: archiving
echo "(3/4) Archiving..." | tee -a "${LOGF}"

if [[ ! -w $BAKDIR ]]; then
	echo "ERROR: No access to backup directory." >>$LOGF
	exit 1
fi

tar -czvf "${BAKDIR}/${TARFILE}" -C "${TEMPDIR}" . &>>$LOGF

if [ $? -ne 0 ]; then echo "ERROR: archivation failed." >>$LOGF; exit 1; fi

# Step 04: remove old backups
echo "(4/4) Remove old backups" | tee -a "${LOGF}"

find "${BAKDIR}" -mtime +"${AUTOREMOVE}" -type f -delete -print &>>$LOGF

if [ $? -ne 0 ]; then echo "WARNING: autoremove old backups failed." >>$LOGF; fi

# Done
echo -e "Backup completed.\n$(stat "${BAKDIR}/${TARFILE}")" | tee -a "${LOGF}"

exit
