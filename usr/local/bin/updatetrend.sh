#!/bin/bash
#
# Script to update *.csv from comms gateway to server. Also updates trendgraphs.
#
VERSION=1.0.0
source /etc/bluecube/cgw.conf

for UNIT in ${MQI[@]}
do 
	ssh olma@46.235.226.48 "~/private/plot/trendmaker_${CLI}.sh ${UNIT}"
done
