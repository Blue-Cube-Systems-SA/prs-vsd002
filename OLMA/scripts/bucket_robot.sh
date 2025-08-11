#!/bin/bash
# Usage: ./bucket_robot.sh Datestring 
# "Datestring" Is when the 'normal sample window' ends.
# This script calls a backend script.
# Odds of execution will increase as the remaining minutes in the 'normal sample window' decrease.
# When the Datestring is in the past (window <0), the odds of execution will be 100%.
#====================================================================================

let NOW=$(date +%s)/60
let WHEN=$(date +%s --date="$1")/60
let WINDOW=$WHEN-$NOW
echo $WINDOW minutes left

if [ -d "/OLMA/OLMA-A/" ]   # Test if  machine is mutiplex
then
    /OLMA/scripts/bucket_robot_backend.sh "$WINDOW" '/OLMA/OLMA-A'
    /OLMA/scripts/bucket_robot_backend.sh "$WINDOW" '/OLMA/OLMA-B'
else
    /OLMA/scripts/bucket_robot_backend.sh "$WINDOW" '/OLMA'
fi
