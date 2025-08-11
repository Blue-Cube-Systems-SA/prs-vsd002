#!/bin/bash

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
_=/usr/bin/printenv

rebootFile=/OLMA/lastReboot.log
waitfile=/OLMA/rebootwait.var
serialstatusfile=/OLMA/serialStatus.log

if [ -f "$waitfile" ]; then
	waitperiod=$(<$waitfile);
else
	waitperiod=15;
	echo "$waitperiod" > $waitfile;
fi

if [ -f "$rebootFile" ] && ![ -s "$rebootFile" ]; then
	lastRebootDate=$(<$rebootFile);
else
	echo "No reboot log present";
	lastRebootDate=0;
fi

mx-uart-ctl -p 0 > $serialstatusfile;
if grep -q "RS422/RS485-4W" $serialstatusfile; then
	echo $(<$serialstatusfile);
	waitperiod=15;
	echo "$waitperiod" > $waitfile;
else
	echo $(<$serialstatusfile);
	currentDate=$(date +%s);
	dateDiff=$(( (($currentDate) - ($lastRebootDate) )/(60) ));
	if [ $dateDiff -ge $waitperiod ]; then
		date +%s > $rebootFile;
		date >> /OLMA/reboots.log;
		waitperiod=$(( ($waitperiod)*2 ));
		echo "$waitperiod" > $waitfile;
		echo "rebooting"
		reboot 
	fi
fi
