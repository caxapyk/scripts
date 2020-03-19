#!/bin/bash

# Directory backup script (mirroring)
#
# Alexander Sakharuk <saharuk.alexander@gmail.com>, 2020
# Licensed under MIT licence
#
# Add to crontab (crontab -e)
# 0 0 * * * /<path>/rbackup.sh
#

SOURCE="/path/to/source"
DEST="/path/to/destination"

TIMESTAMP=$(date +%d-%m-%Y_%H-%M)

LOGFILE="/var/log/rbackup.log"

# Renew logfile
echo -e "${TIMESTAMP} Backup started" | tee "${LOGFILE}"

# Rsync
rsync -avz \
        --exclude=efp/* \
        --exclude=emk/* \
        --exclude=data/* \
        --exclude=share/Бухгалтерия/* \
        --exclude=share/Генеалогия/* \
        --exclude=share/ГХФ/* \
        --exclude=share/Директор/* \
        --exclude=share/ЗамДиректора/* \
        --exclude=share/Инженер/* \
        --exclude=share/НСА/* \
        --exclude=share/ОИиПД/* \
        --exclude=share/ОКВАиД/* \
        --exclude=share/ООСД/* \
        --exclude=share/ОПОД/* \
        --exclude=share/Сайт/* \
        --exclude=share/Секретарь/* \
        --exclude=share/СтСправок/* \
        --exclude=share/ЧитЗал/* \
        --delete \
        --stats \
        --progress \
        $SOURCE \
        $DEST | tee -a "${LOGFILE}"

if [ $? -ne 0 ]; then echo "ERROR rsync failed"; >>$LOGF exit 1; fi

# Done
echo -e "Backup completed" | tee -a "${LOGFILE}"