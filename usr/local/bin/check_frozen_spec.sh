#!/bin/bash

: '
This script monitors the tosend file to check if the spectrometer is frozen or not.
It will then reboot the Optical Processor if frozen for too long.
'

VERSION=1.0.0-arm

source /etc/bluecube/terminal_colours.conf

# Get the hostname
hostname=$(hostname)
# Extract CLIENT and MQI from the hostname
CLIENT=${hostname:0:3}
MQI=${hostname:3}

# Define file paths
tosendFile="/OLMA/data/${CLIENT}${MQI}_tosend"
logFile="/OLMA/data/OP_reboot.log"
flagFile="/OLMA/input/oiu-power.flag"
trainingConfFile="/OLMA/conf/training.conf"

# Function to log messages to the log file
log() {
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $1" >> "$logFile"
}

# Function to get the column index for T-Offset
getTOffsetColumn() {
    local trainingConf=$1
    local tOffsetLine=$(grep -i 'Mineral.*=T-Offset' "$trainingConf")
    local tOffsetNumber=$(echo "$tOffsetLine" | grep -o '[0-9]*')
    local tOffsetColumn=$((tOffsetNumber + 2))
    echo $tOffsetColumn
}

# Get the T-Offset column index
tOffsetColumn=$(getTOffsetColumn "$trainingConfFile")

# Get the last five lines of the tosend file and extract the TOffset values
tOffsets=($(tail -n 5 "$tosendFile" | awk -F ',' -v col="$tOffsetColumn" '{print $col}'))

# Read the first number from the array
firstNumber=$(echo "${tOffsets[0]}" | tr -d '[:space:]')

# Iterate through the array and compare each value with the first number
for tOffset in "${tOffsets[@]}"; do
    # Remove leading and trailing whitespaces from the value
    tOffset=$(echo "$tOffset" | tr -d '[:space:]')

    # Check if the value is empty
    if [ -z "$tOffset" ]; then
        continue
    fi

    # Compare the value with the first number
    if [ "$tOffset" != "$firstNumber" ]; then
        echo -e "${COLOR_GREEN}T-Offset changed in the last 5 minutes. Not rebooting the Optical Processor.${COLOR_RESET}"
        exit 0
    fi
done

# Log and power cycle the Optical Processor
echo -e "${COLOR_RED}T-Offset has not changed in the last 5 minutes. Rebooting Optical Processor.${COLOR_RESET}"
log "T-Offset has not changed in the last 5 minutes. Rebooting Optical Processor."
touch "$flagFile"
