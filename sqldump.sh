#!/bin/bash

# 
# MySQL/MariaDB database backup script
#
# Alexander Sakharuk <saharuk.alexander@gmail.com>,  2020
# Licensed under MIT licence
#
# Examples
#
# Make backup of `test` and `test2` DATABASE to the current directory
# sqldump -d . -u <dbusername> -p <dbp@s$w0rd> -b "test test2"
#
# Add sqldump to cron (crontab -e)
# 0 0 * * * /<path to sqldump script>/sqldump.sh -d <path> -s localhost -u <dbusername> -p <dbp@ssw0rd>
#

#
# DEFAULTS
#

SERVER="localhost"
DBUSER="root"
DBPASS=""

TEMPDIR="/tmp/backups/db"
LOGF="/var/log/mysqldump.log"

TIMESTAMP=$(date +%d-%m-%Y_%H-%M)
TARFILE="mysqldump-${TIMESTAMP}.tar.gz"

RDAYS=14

#
# FUNCTIONS
#

# Function print help message
function help() {
cat <<EOF
MySQL/MariaDB database backup script (Version 0.1)

Usage: sqldump [opts]

OPTIONS
-d <path>		Backup directory (/var/backup/db)
-h			Print help
-r <days>		Auto remove old backups after ? days (default: after 14 days).
-t <path>		Temp directory (/var/backup/mariadb) 
-s <address>			Server name/IP (default: localhost)
-b <database/s>	Database name (or space separated list)
-u <username> 		MySQL user
-p <pass>		MySQL password

EOF
exit 0;
}

if [[ $# -eq 0 ]]; then help; exit 0; fi 

#
# PARSE OPTONS
#

while getopts ":b:d:h:r:t:s:u:p:" opt; do
	case $opt in
		b) DATABASE="${OPTARG}"
		;;
		d) BAKDIR="${OPTARG}"
		;;
		h) help
		;;
		p) DBPASS="${OPTARG}"
		;;
		r) RDAYS="${OPTARG}"
		;;
		s) SERVER="${OPTARG}"
		;;
		t) TEMPDIR="${OPTARG}"
		;;
		u) DBUSER="${OPTARG}"
		;;
		/?) echo "Invalid option ${OPTARG}" >>$LOGF
		;;
	esac
done

#
# CHECKS
#

# Renew logfile
echo "${TIMESTAMP} Mysql dump started" > $LOGF

# Check database name/list passed
if [[ ! -n "$DATABASE" ]]; then
       echo "ERROR: you must provide database name or list of databases. Use option -b <database/s>." >>$LOGF
       exit 1
fi

# Check backup directory exists
if [[ ! -d "$BAKDIR" ]]; then
       echo "ERROR: you must provide valid backup directory path. Use option -d <dir>." >>$LOGF
       exit 1
fi

# Remove temp
if [[ -d $TEMPDIR ]]; then
	rm -rf "${TEMPDIR}" 2>>$LOGF
	if [ $? -ne 0 ]; then echo "ERROR while trying to remove temp"; >>$LOGF exit 1; fi
fi

# Create temp folder
mkdir -p "${TEMPDIR}" 2>>$LOGF

if [ $? -ne 0 ]; then echo "ERROR while trying to create temp directory: ${TEMPDIR}" >>$LOGF; exit 1; fi

#
# BACKUP
#

# Step 01: mysqldump
echo "(1/3) Dump started" | tee -a "${LOGF}"

# append `mysql` to backup priveleges
DATABASE="${DATABASE} mysql"

for DB in ${DATABASE}
do
	# dump each database in a separate file
	mysqldump --opt --protocol=TCP --single-transaction --user=${DBUSER} --password=${DBPASS} --host=${SERVER} "$DB" > "${TEMPDIR}/${DB}.sql"
done

if [ $? -ne 0 ]; then echo "ERROR: mysqldump failed" >>$LOGF; exit 1; fi

# Step 02: archiving
echo "(2/3) Archiving..." | tee -a "${LOGF}"

if [[ ! -w $BAKDIR ]]; then
	echo "ERROR: No access to backup directory." >>$LOGF
	exit 1
fi

tar -czvf "${BAKDIR}/${TARFILE}" -C "${TEMPDIR}" . &>>$LOGF

if [ $? -ne 0 ]; then echo "ERROR: archivation failed." >>$LOGF; exit 1; fi


# Step 03: remove old dumps
echo "(3/3) Remove old dumps" | tee -a "${LOGF}"

find "${BAKDIR}" -mtime +"${RDAYS}" -type f -delete -print &>>$LOGF

if [ $? -ne 0 ]; then echo "WARNING: autoremove old dumps failed." >>$LOGF; fi

# Done
echo -e "Backup completed.\n$(stat "${BAKDIR}/${TARFILE}")" | tee -a "${LOGF}"

exit 0