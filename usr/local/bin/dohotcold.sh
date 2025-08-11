#!/bin/bash

# The purpose of this script is to take 18 .dak file at different temperatures with the light ON and OFF
# These files are then used to see how the spectrum is affected with the spectrometer at different temperatures
# This script is only used during the Quality Assurance (QA) process when the MQi is being manufactured

VERSION="1.1-arm"

log_file="/OLMA/data/dohotcold.log"

log() {
    local message="$1"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $message" >> $log_file
}

# Check if mq200embed is running or not
is_mq200embed_running() {
    local process_count=$(ps -aux | grep -c "mq200embed")

    if [ "$process_count" -gt 1 ]; then
        # mq200embed is running; do nothing
        :
    else
        echo "mq200embed is not running. Exiting the script"
        log "mq200embed is not running. Exiting the script"
    fi
}

backup_config() {
    echo "Making backup of heater.conf (heater.conf.bak)"
    log "Making backup of heater.conf (heater.conf.bak)"
    cp -p heater.conf heater.conf.bak
}

restore_original_config() {
    echo "Restoring heater.conf back to original temperature offset setpoint"
    log "Restoring heater.conf back to original temperature offset setpoint"
    cp -p heater.conf.bak heater.conf
    touch input/reloadh.flag
}

check_for_mq200.conf.bak() {
    if [ -e /OLMA/mq200.conf.bak ]; then
        echo "Found mq200.conf.bak, running stoplux.sh"
        log "Found mq200.conf.bak, running stoplux.sh"
        scripts/stoplux.sh
    fi
}

run_light_scan() {
    local temp_offset_name=$1
    local temp_offset=$2

    check_for_mq200.conf.bak
    echo "Running startlight.sh"
    log "Running startlight.sh"
    scripts/startlight.sh
    sleep 100
    # Take 3 .dak files at a certain temperature with the bulb switched ON
    for i in {1..3}; do
        # Check if mq200embed is running
        is_mq200embed_running
        echo "Running light scan $i for $temp_offset_name temperature offset ($temp_offset)."
        log "Running light scan $i for $temp_offset_name temperature offset ($temp_offset)."
        touch input/red.flag
        sleep 300
    done
    scripts/stoplux.sh
    sleep 100
}

run_dark_scan() {
    local temp_offset_name=$1
    local temp_offset=$2

    check_for_mq200.conf.bak
    echo "Running startdark.sh"
    log "Running startdark.sh"
    scripts/startdark.sh
    sleep 100
    # Take 3 .dak files at a certain temperature with the bulb switched OFF
    for i in {1..3}; do
        # Check if mq200embed is running
        is_mq200embed_running
        echo "Running dark scan $i for $temp_offset_name temperature offset ($temp_offset)."
        log "Running dark scan $i for $temp_offset_name temperature offset ($temp_offset)."
        touch input/red.flag
        sleep 300
    done
    scripts/stoplux.sh
    sleep 100
}

change_temp_offset() {
    local temp_offset_name=$1
    local temp_offset=$2

    echo "Setting setpoint to $temp_offset_name temperature offset ($temp_offset)."
    log "Setting setpoint to $temp_offset_name temperature offset ($temp_offset)."
    sed "s/offset=${tempOffsetSetting}/offset=${temp_offset}/" heater.conf.bak > heater.conf
    touch input/reloadh.flag
    # Give the optical processor time to adjust to the new temperature offset setpoint
    echo "Waiting 6500 seconds (108 minutes) for optical processor to adjust to new setpoint"
    log "Waiting 6500 seconds (108 minutes) for optical processor to adjust to new setpoint"
    sleep 6500
}

echo "Starting Hot-Cold"
log "Starting Hot_cold"

tempOffsetSetting=$( awk -F'=' '$1 == "offset" {print $2}' /OLMA/heater.conf ); # read t_offset from file to get upper and lower limits
tempOffsetLowerLim=$( awk -v n1=$tempOffsetSetting -v n2=15 'BEGIN{print n1-n2}' );
tempOffsetUpperLim=$( awk -v n1=$tempOffsetSetting -v n2=15 'BEGIN{print n1+n2}' );

cd /OLMA
backup_config

# Original T-OFFSET
run_light_scan "original" "$tempOffsetSetting"
run_dark_scan "original" "$tempOffsetSetting"

# Upper T-OFFSET (Lower Temp)
change_temp_offset "lower" "$tempOffsetUpperLim"
run_light_scan "lower" "$tempOffsetUpperLim"
run_dark_scan "lower" "$tempOffsetUpperLim"

# Lower T-OFFSET (Higher Temp)
change_temp_offset "higher" "$tempOffsetLowerLim"
run_light_scan "higher" "$tempOffsetLowerLim"
run_dark_scan "higher" "$tempOffsetLowerLim"

# Restore original T-OFFSET
restore_original_config
