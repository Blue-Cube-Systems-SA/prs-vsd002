#!/bin/bash

: '
This script generates trend.csv files used to plot data on Webtrends.
The script executes trendline scripts and then pipes the values into the trend.csv files
'

VERSION=1.0-arm

source /etc/bluecube/terminal_colours.conf

HOSTNAME=$(hostname)
CLI=${HOSTNAME:0:3}
UNIT=${HOSTNAME:3}

MONTH=$(date +%Y%m)

echo -e "${COLOR_CYAN}Running tosendline.sh to create trend.csv file ${COLOR_RESET}"
if [ ! -f /tmp/tosendline$UNIT$MONTH.flag ]
then
	/usr/local/bin/trendline_s.sh Fieldnames >> /OLMA/data/${CLI}${UNIT}_trend_${MONTH}.csv 
	/usr/local/bin/trendline_s.sh Descriptions >> /OLMA/data/${CLI}${UNIT}_trend_${MONTH}.csv
	touch /tmp/tosendline$UNIT$MONTH.flag
fi

/usr/local/bin/trendline_s.sh >> /OLMA/data/${CLI}${UNIT}_trend_${MONTH}.csv