#!/bin/bash
#
# Script to send *.dak to CAM
#
VERSION=1.0.0

source /etc/bluecube/cgw.conf

for UNIT in ${MQI[@]}
do 
	rsync -avz /var/OLMA/updates/*${UNIT}* ${UNIT}:/var/OLMA/updates/
done

