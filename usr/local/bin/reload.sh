#!/bin/bash

: '
This script loads different calibration models based on the current ore type received from the SCADA. 
It initializes variables for the current calibration and SCADA data files, categorizes ore types 
into calibration models, reads current and SCADA-provided ore types, determines a new calibration folder 
based on SCADA data, and updates the system with the corresponding calibration files if found.
'

VERSION=1.2.0-arm

currCalFile=/OLMA/cal/current_cal.txt
scadaFile=/OLMA/data/profibus_read.csv

# Source the configuration file
source /etc/bluecube/mqi.conf
source /etc/bluecube/terminal_colours.conf

# Initialize an associative array to categorize ore types
declare -A calFolders

# Categorise different ore types received from the SCADA into different calibration models
# Dynamically populate the associative array with the variables from the configuration file
for ((i=0; i<NUM_CAL_MODELS; i++)); do
    folderLetter=$(printf "\x$(printf %x $((65 + i)) )")  # Convert number to corresponding ASCII letter (A, B, C, ...)
    calFolders[$folderLetter]=$(eval echo \$$folderLetter) # Assign the value from the sourced variable
done

# Fetch the currently loaded calibration model
if [ -f "${currCalFile}" ]; then
    currLoadedCal=$(<${currCalFile})
    if [ -z "$currLoadedCal" ]; then
        # The file exists but is empty, error
        echo -e "${COLOR_RED}The file $currCalFile is empty or contains no valid data.${COLOR_RESET}"
        exit 1
    fi
else
    # No loaded seam file, error
    echo -e "${COLOR_RED}Could not load from $currCalFile ${COLOR_RESET}"
    exit 1
fi

# Read current ore type byte received from the SCADA
if [ -f "$scadaFile" ]; then
    scadaOreTypeByteReceived=$(tail -1 "$scadaFile" | awk -F, '{ print $4 }')
else
    # Assume a default value if the file was not found
    scadaOreTypeByteReceived=0
fi

# If a valid byte was received from the SCADA
if [ ${scadaOreTypeByteReceived} -ne 0 ]; then 
    echo -e "${COLOR_CYAN}The current calibration folder is $currLoadedCal ${COLOR_RESET}"

    # Determine the new calibration folder based on the received ore type
    newCalFolder=""

    # Loop through each key (folder) in the calFolders associative array
    for folder in "${!calFolders[@]}"; do
        # Split the values associated with the current folder into an array
        IFS=' ' read -r -a values <<< "${calFolders[$folder]}"
        # Iterate over each value for the current folder
        for value in "${values[@]}"; do
            # Check if the current value matches the received ore type
            if [[ "$value" == "$scadaOreTypeByteReceived" ]]; then
                # If the condition is met, set the newCalFolder variable and exit the loop
                newCalFolder="$folder"
                break 2  # Break out of both loops
            fi
        done
    done

    # If a matching calibration folder was found for the ore type
    if [ ! -z "$newCalFolder" ]; then
        # Find the directory in /OLMA/cal/ that starts with the newCalFolder letter
        calDir=$(find /OLMA/cal/ -maxdepth 1 -type d -name "${newCalFolder}*")
        calFolderName=$(basename "$calDir")

        # If no directory was found starting with the newCalFolder letter
        if [ -z "$calDir" ]; then
            echo -e "${COLOR_RED}No directory found starting with ${newCalFolder} in /OLMA/cal/ ${COLOR_RESET}"
        else
            # Print the newly determined calibration folder
            echo -e "${COLOR_GREEN}New calibration folder is ${calFolderName} ${COLOR_RESET}"

            # If the found directory is different from the currently loaded calibration
            if ! [ "$calFolderName" = "$currLoadedCal" ]; then
                # Print message indicating the old calibration has been overwritten
                echo -e "${COLOR_GREEN}Current and new ore types differ. Overwriting old calibration model (${currLoadedCal}) with new calibration model (${calFolderName}) ${COLOR_RESET}"
                # Copy all files from the found directory to /OLMA/conf/ directory, with error handling
                cp -a "${calDir}"/* /OLMA/conf/ || {
                    echo -e "${COLOR_RED}Error copying files from ${calDir} to /OLMA/conf/ ${COLOR_RESET}"
                    exit 1
                }

                # Update the current calibration folder file with the new folder name
                echo -e "${calFolderName}" > ${currCalFile}
                # Create a flag file to signal system reload
                touch /OLMA/input/reload.flag
            else
                # Print message indicating the new and current calibration folders are the same
                echo -e "${COLOR_GREEN}Current and new ore types are the same. Not changing calibration model. ${COLOR_RESET}"
            fi
        fi
    else
        echo -e "${COLOR_RED}No matching calibration folder found for ore type ${scadaOreTypeByteReceived} ${COLOR_RESET}"
    fi
else
    echo -e "${COLOR_RED}No ore type received from SCADA ${COLOR_RESET}";
fi
