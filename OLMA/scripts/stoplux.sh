#!/bin/bash

BACKUPFILE="mq200.conf.bak"

cd /OLMA
mv ${BACKUPFILE} mq200.conf
touch /OLMA/input/reload.flag
exit 0
