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
#

#
# DEFAULTS
#

AUTOREMOVE=10
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
		/?) echo "Invalid option ${OPTARG}" >&2
		;;
	esac
done

#
# PRE-ACTIONS
#

# Check Percona XtraBackup installed
if [[ ! -x "$(command -v xtrabackup)" ]]; then 
	echo "ERROR: 'extrabackup' utility not found." \
	       "\n Go to https://www.percona.com/doc/percona-xtrabackup/LATEST/installation.html" >&2 
	exit 1
fi

# Remove temp
if [[ -d $TEMPDIR ]]; then
	rm -rf "${TEMPDIR}" 2>&1
	if [ $? -ne 0 ]; then echo "ERROR while trying to remove temp"; exit 1; fi
fi

# Check backup directory exists
if [[ ! -d "$BAKDIR" ]]; then
       echo "ERROR: you must provide valid backup directory path. Use option -d <dir>." >&2
       exit 1
fi

# Create temp folder structure
mkdir -pv "${TEMPDIR}" \
	"${TEMPDIR}/var/lib/mysql" \
	"${TEMPDIR}/etc" \
	"${TEMPDIR}/usr/lib" \
	"${TEMPDIR}/usr/share"

if [ $? -ne 0 ]; then echo "ERROR while trying to create temp directory: ${TEMPDIR}" >&2; exit 1; fi

#
# BACKUP
#

# Step 01: backup DB with Percona XtraBackup
echo "(1/4) MySQL backup"

# Make a backup and place it in xtrabackup --target-dir
xtrabackup --backup \
	--user="${DBUSER}" \
	--password="${DBPASS}" \
	--no-timestamp \
	--target-dir="${TEMPDIR}/var/lib/mysql"

if [ $? -ne 0 ]; then echo "ERROR: exrabackup returned the error code. Database backup failed." >&2; exit 1; fi

# Makes xtrabackup perform recovery on a backup so that it is ready to use
xtrabackup --prepare \
	--apply-log-only \
	--target-dir="${TEMPDIR}/var/lib/mysql"

if [ $? -ne 0 ]; then echo "ERROR: exrabackup returned error code. Database preparation failed." >&2; exit 1; fi

# Step 02: sync zabbix files
echo "(2/4) Copying Zabbix files"

rsync -avz /etc/zabbix "${TEMPDIR}/etc/" &&
rsync -avz /usr/lib/zabbix "${TEMPDIR}/usr/lib/" &&
rsync -avz /usr/share/zabbix "${TEMPDIR}/usr/share/"

if [ $? -ne 0 ]; then echo "ERROR while trying to synchronize Zabbix files:" >&2; exit 1; fi

# Step 03: archiving
echo "(3/4) Archiving..."

if [[ ! -w $BAKDIR ]]; then
	echo "ERROR: No access to backup directory."
	exit 1
fi

tar -czvf "${BAKDIR}/${TARFILE}" -C "${TEMPDIR}" .

if [ $? -ne 0 ]; then echo "ERROR: archivation failed." >&2; exit 1; fi

# Step 04: remove old backups
echo "(4/4) Remove old backups..."

find "${BAKDIR}" -mmin +"${AUTOREMOVE}" -type f -delete -print

if [ $? -ne 0 ]; then echo "WARNING: autoremove old backups failed."; fi

# Done
echo -e "Backup completed.\n$(stat "${BAKDIR}/${TARFILE}")"

exit
