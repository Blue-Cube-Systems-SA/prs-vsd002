#!/bin/bash

# This file's purpose is to generate the daily.csv file that will be used in the Webtrends' Statistics
# It is primarily used for debugging and monitoring the status of the MQi
# It appends how much memory is available and used and whether mqsembed and mq200embed are running 

VERSION="2.4.1-arm"           # V2 Units
source /etc/bluecube/cgw.conf

# Cycle through all the units and run these commands from the gateway
for UNIT in ${MQI[@]}
do
	# Get today's date
	ssh -n $UNIT "echo -n $(date +%Y%m%d-%H%M), >> /OLMA/data/${CLI}_${UNIT}_daily.csv"

        # Free memory
	ssh -n $UNIT "echo -n `free | grep 'Mem' | awk '{print $4}'`, >> /OLMA/data/${CLI}_${UNIT}_daily.csv"

	# Free Root
	ssh -n $UNIT "echo -n `df | grep '/dev/mmcblk0p2' | awk '{print $4}'`, >> /OLMA/data/${CLI}_${UNIT}_daily.csv"

	# Free Overlay
	ssh -n $UNIT "echo -n `df | grep '/dev/mmcblk0p3' | awk '{print $4}'`, >> /OLMA/data/${CLI}_${UNIT}_daily.csv"

	# Get the unit's uptime (but convert seconds to minutes)
	uptime_min=$(ssh -n $UNIT "cat /proc/uptime | cut -d ' ' -f1 | awk '{print int(\$1 / 60)}'")
	ssh -n $UNIT "echo -n '$uptime_min,' >> /OLMA/data/${CLI}_${UNIT}_daily.csv"

	# Check if mqsembed is running or not (IF not running, write 0 ELSE write 1 if running) 
	ssh -n $UNIT "if [ `ps -aux | grep "/OLMA/mqsembed" | grep -v "grep" | grep -c "/OLMA/mqsembed"` -ne 1 ]; then echo -n '0', >> /OLMA/data/${CLI}_${UNIT}_daily.csv; else echo -n '1', >> /OLMA/data/${CLI}_${UNIT}_daily.csv; fi"

	# Check if mq200embed is running or not (IF not running, write 0 ELSE write 1 if running) 
	ssh -n $UNIT "if [ `ps -aux | grep "/OLMA/mq200embed" | grep -v "grep" | grep -c "/OLMA/mq200embed"` -ne 1 ]; then echo -n '0', >> /OLMA/data/${CLI}_${UNIT}_daily.csv; else echo -n '1', >> /OLMA/data/${CLI}_${UNIT}_daily.csv; fi"


	# Check if getspec is running or not (IF not running, write 0 ELSE write 1 if running) 
	ssh -n $UNIT "if [ `ps -aux | grep "/OLMA/getspec" | grep -v "grep" | grep -c "/OLMA/getspec"` -ne 1 ]; then echo -n '0', >> /OLMA/data/${CLI}_${UNIT}_daily.csv; else echo -n '1', >> /OLMA/data/${CLI}_${UNIT}_daily.csv; fi"


	# Get the last date that a luxcomp was done (but remove the / to make it an integer for the Webtrends.
	# The integer is a decimal to prevent the Webtrends from scaling to a very large number due to the date in an integer form
	ssh -n $UNIT "echo -n `head -n 1 /OLMA/conf/luxcomp.csv | cut -c21-31 | sed 's/\///g' | sed 's/2/.2/'` >> /OLMA/data/${CLI}_${UNIT}_daily.csv"

	# Add a newline at the end of the line
	ssh -n $UNIT "echo \"\" >> /OLMA/data/${CLI}_${UNIT}_daily.csv"
done

