#!/bin/bash

BACKUPFILE="mq200.conf.bak"
INTEGRATION_MS=32
AVERAGE=120

cd /OLMA

if [ -e ${BACKUPFILE} ]; then
	echo "Please run stoplux.sh first"
	exit -1
fi

cp -a mq200.conf ${BACKUPFILE}
sed s/'Channel0Integration=.*'/'Channel0Integration='${INTEGRATION_MS}/ ${BACKUPFILE} | sed s/'StrobeEnabled=.*'/'StrobeEnabled=1'/ | sed s/'Channel0Average=.*'/'Channel0Average='${AVERAGE}/ | sed s/'^FlashDelay=.*'/'FlashDelay=0'/ > mq200.conf
touch /OLMA/input/reload.flag
exit 0
