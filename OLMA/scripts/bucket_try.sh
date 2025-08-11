#!/bin/bash
FLOW=`sed 's/,.*$//' /OLMA/data/profibus_read.csv`
DENS=`sed -e 's/^[^,]*,//' -e 's/,.*$//' /OLMA/data/profibus_read.csv`
if [ -f /OLMA/input/bucket_empty.flag ]
then 
    if [ "$FLOW" -gt "400" ]
    then
        if [ "$DENS" -gt "1200" ]
        then
            echo ja
            rm /OLMA/input/bucket_empty.flag
            /OLMA/scripts/green.sh
            touch /OLMA/input/bucket_full.flag
        else echo density $DENS
        fi
    else echo flow $FLOW
    fi
else echo flag
fi 

