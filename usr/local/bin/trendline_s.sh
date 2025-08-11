#!/bin/bash
VERSION="1.0.0"
# Usually called from CGW crontab
if [ ! -f /tmp/trendlineScalled.flag ]
then 
    /usr/local/bin/trendline.sh '/OLMA/' Fieldnames
    sleep 3
    /usr/local/bin/trendline.sh '/OLMA/' Descriptions
    sleep 3
    touch /tmp/trendlineScalled.flag
fi
/usr/local/bin/trendline.sh '/OLMA/' $1
