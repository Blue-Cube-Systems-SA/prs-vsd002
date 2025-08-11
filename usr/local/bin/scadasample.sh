#!/bin/bash

# This script reads from newest.sample and mqi_status_byte and populates the latest mineral values from it into /OLMA/data/anybus.sample.  
# mqsembed then reads these values from anybus.sample and writes it out to the Anybus.

VERSION=1.1-arm

source /etc/bluecube/scada.conf

# Define paths for temporary and final files
UFSTMP="/tmp/anybus.sample.unit.tmp"  		# Temporary file for each unit's data processing
FSTMP="/tmp/anybus.sample.tmp"  			# Main temporary file to collect data from all units
FS="/OLMA/data/anybus.sample"  				# Final file destination

# Clear the main temporary file to ensure it starts empty
echo -n "" > ${FSTMP}

# Initialize a counter for unit processing
i=1
# Loop through each unit listed in the MQI array from the sourced config file
for UNIT in ${MQI[@]}
do
    # Securely copy the newest sample and status byte files from the unit to local machine
    scp -p ${UNIT}:/OLMA/data/newest.sample /OLMA/data/newest${i}.sample
    scp -p ${UNIT}:/OLMA/data/mqi_status_byte /OLMA/data/mqi_status_byte${i}

    # Filter the copied sample file to remove lines with @@@ and $$$, keeping only the first 8 lines
    grep -v @@@ /OLMA/data/newest${i}.sample | grep -v $$$ | head -n 8 > ${UFSTMP}

    # Check if the mqi_status_byte file exists and is not empty, otherwise set MQi_status to zero
    if [ -s /OLMA/data/mqi_status_byte${i} ]; then
        MQi_status=$(</OLMA/data/mqi_status_byte${i})
    else
        MQi_status=0  # Set to zero if the file does not exist or if it is empty
    fi
    echo "$MQi_status" >> ${UFSTMP}

    # Ensure the unit's temporary file has exactly 9 lines by padding with zeros if necessary,
    # then append the result to the main temporary file
    yes 0 | cat ${UFSTMP} - | head -n 9 >> ${FSTMP}

    # Increment the unit counter
    i=$(( ${i} + 1 ))
done

# Move the fully assembled temporary file to the final destination, replacing any existing file
mv ${FSTMP} ${FS}
