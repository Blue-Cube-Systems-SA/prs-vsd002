#!/bin/bash

# The purpose of this script is to monitor the amount of instances of each service
# and to restart the binaries if they have crashed and are not running

VERSION="1.2-arm"

logFile="/OLMA/data/checkbin.log"

# Function to log messages to the log file
log() {
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $1" >> "$logFile"
}

# Function to check instances and restart the service if needed
check_instances_and_restart() {
    service_name=$1
    service_dir=$2

    service_name_and_path="${service_dir}/${service_name}"

    # Count the number of instances of the service
    num_instances=$(ps aux | grep "$service_name_and_path" | grep -vc "grep")

    # Check conditions for restarting the service
    if [ "$num_instances" -eq 1 ]; then
        # No need to restart, this is normal
        echo "Not restarting $service_name"
    else
        echo "Restarting $service_name (num_instances=$num_instances)"
        log "Restarting $service_name (num_instances=$num_instances)"

        systemctl stop "$service_name".service

        killall "$service_name"
        if [ "$service_name" == "mq200embed" ]; then
            killall sampleDetector
	    touch /OLMA/input/reloadcpipe.flag
        fi

        sleep 5

        if [ "$service_name" == "mqsembed" ]; then
            touch /OLMA/input/sample.sem
        fi
        systemctl start "$service_name".service
    fi
}

# Call the function for each service
check_instances_and_restart "getspec" "/OLMA"
check_instances_and_restart "Calcaverages" "/OLMA/scripts"
check_instances_and_restart "heater" "/OLMA"
check_instances_and_restart "modbus" "/OLMA"
check_instances_and_restart "mq200embed" "/OLMA"
check_instances_and_restart "mqsembed" "/OLMA"
