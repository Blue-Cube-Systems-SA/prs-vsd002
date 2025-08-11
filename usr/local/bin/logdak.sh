#!/bin/bash

# Script to get various files from each of the connected units and sync them down to the communications gateway
# These files will later be sent to the servers for storage

VERSION=1.5-arm

source /etc/bluecube/cgw.conf
source /etc/bluecube/terminal_colours.conf
source /etc/bluecube/mqi.conf

lockFile="/OLMA/input/logdak.lock"
logFile="/OLMA/data/logdak.log"

# Function to log messages to the log file
log() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $1" >> "$logFile"
}

# Function to check and delete old lock file
check_lock_file() {
    # Check if the lock file exists
    if [ -e "$lockFile" ]; then
        # Calculate the age of the lock file in minutes
        local lock_age=$(( ($(date +%s) - $(stat -c %Y "$lockFile")) / 60 ))

        # Check if the lock file is older than the specified maximum age
        if [ $lock_age -ge $logdakLockFileMaxAgeMin ]; then
            echo -e "${COLOR_RED}Lock file was more than $logdakLockFileMaxAgeMin minutes old ($lock_age minutes old). Removing.${COLOR_RESET}"
            log "Lock file was more than $logdakLockFileMaxAgeMin minutes old ($lock_age minutes old). Removing."

			# Remove the lock file if its older than the maximum age
            rm -f "$lockFile"
        else
			# Keep the lock file there if its not older than the maximum age
            echo -e "${COLOR_CYAN}Lock file found. Exiting.${COLOR_RESET}"
            log "Lock file found. Exiting."
            exit 1
        fi
    fi
}


# Function to execute rsync with timeout and logging
execute_rsync() {
    # Capture the rsync command passed as argument
    local rsync_command="$1"

    # Execute rsync command with specified timeout
    timeout $rsyncTimeoutSec $rsync_command

    # Capture the exit code of rsync command after it was executed
    local exit_code=$?

    # Check if rsync command timed out
    if [ $exit_code -eq 124 ]; then
        echo -e "${COLOR_RED}TIMEOUT - Rsync command '$rsync_command' timed out after $rsyncTimeoutSec seconds. ${COLOR_RESET}"
        log "TIMEOUT - Rsync command '$rsync_command' timed out after $rsyncTimeoutSec seconds."
        return 1
    # Check if rsync command failed (exit code other than 0)
    elif [ $exit_code -ne 0 ]; then
        echo -e "${COLOR_RED}Failed to execute Rsync command '$rsync_command': $rsync_output ${COLOR_RESET}"
        return 1
    else
        # If rsync command executed successfully
        return 0
    fi
}


# Create a lock file to prevent multiple instances
check_lock_file
touch "$lockFile"

# Ensure lock file is deleted on script exit
trap "rm -f $lockFile" EXIT

MONTH=`date +%Y%m`

# Fetch daily.csv files from communications gateway
echo -e "${COLOR_GREEN}Fetching daily.csv from communications gateway ${COLOR_RESET}"
if find /var/OLMA/dak -maxdepth 1 -type f -name '*_daily.csv' -print -quit | grep -q .; then
	execute_rsync "rsync -avz /OLMA/data/*_daily.csv /var/OLMA/dak/"
else
	echo -e "${COLOR_RED}No daily.csv files found on the communications gateway ${COLOR_RESET}"
fi

# Loop through all the units
for UNIT in ${MQI[@]}
do
	echo -e "${COLOR_GREEN}SSH into ${UNIT} ${COLOR_RESET}"

	# Fetch .dak files from unit
	echo -e "${COLOR_CYAN}Fetching all .dak files ${COLOR_RESET}"
	if ssh $UNIT 'find /OLMA/data -maxdepth 1 -type f -name "*.dak" | grep -q .'; then
		execute_rsync "rsync -avz ${UNIT}:/OLMA/data/*.dak /var/OLMA/dak/"
	else
		echo -e "${COLOR_RED}No .dak files on ${UNIT} ${COLOR_RESET}"
	fi

	# Fetch trend.csv files from unit
	echo -e "${COLOR_CYAN}Fetching all trend.csv files ${COLOR_RESET}"
	if ssh $UNIT 'find /OLMA/data -maxdepth 1 -type f -name "*trend*.csv" | grep -q .'; then
		execute_rsync "rsync -avz ${UNIT}:/OLMA/data/*trend*.csv /var/OLMA/dak/"
	else
		echo -e "${COLOR_RED}No trend.csv files found on ${UNIT} ${COLOR_RESET}"
	fi

	# Fetch sample_averages.csv files from unit
	echo -e "${COLOR_CYAN}Fetching all sample_averages.csv files ${COLOR_RESET}"
	if ssh $UNIT 'find /OLMA/data -maxdepth 1 -type f -name "*sample_averages.csv" | grep -q .'; then
		execute_rsync "rsync -avz ${UNIT}:/OLMA/data/*sample_averages.csv /var/OLMA/dak/"
	else
		echo -e "${COLOR_RED}No sample_averages.csv files found on ${UNIT} ${COLOR_RESET}"
	fi

	# Fetch averages .csv files from unit
	echo -e "${COLOR_CYAN}Fetching all averages .csv files ${COLOR_RESET}"
	if ssh $UNIT 'find /OLMA/data -maxdepth 1 -type f -name "*_averages_*.csv" | grep -q .'; then
		execute_rsync "rsync -avz ${UNIT}:/OLMA/data/*_averages_*.csv /var/OLMA/dak/"
	else
		echo -e "${COLOR_RED}No averages.csv files found on ${UNIT} ${COLOR_RESET}"
	fi

	# Fetch all daily.csv files from unit
	echo -e "${COLOR_CYAN}Fetching all daily.csv files ${COLOR_RESET}"
	if ssh $UNIT 'find /OLMA/data -maxdepth 1 -type f -name "*_daily.csv" | grep -q .'; then
		execute_rsync "rsync -avz ${UNIT}:/OLMA/data/*_daily.csv /var/OLMA/dak/"
	else
		echo -e "${COLOR_RED}No daily.csv files found on ${UNIT} ${COLOR_RESET}"
	fi

	# Fetch energy_newest.csv files from unit
	echo -e "${COLOR_CYAN}Fetching energy_newest.csv ${COLOR_RESET}"
	if ssh $UNIT 'find /OLMA/data -maxdepth 1 -type f -name "energy_newest.csv" | grep -q .'; then
		execute_rsync "rsync -avz ${UNIT}:/OLMA/data/energy_newest.csv /var/OLMA/dak/"
		mv /var/OLMA/dak/energy_newest.csv /var/OLMA/dak/${UNIT}_energy_newest.csv
	else
		echo -e "${COLOR_RED}No energy_newest.csv files found on ${UNIT} ${COLOR_RESET}"
	fi

	# Fetch SampleOptimiser_Rx.txt files from unit
	echo -e "${COLOR_CYAN}Fetching SampleOptimiser_Rx.txt ${COLOR_RESET}"
	if ssh $UNIT 'find /OLMA/data -maxdepth 1 -type f -name "*SampleOptimiser_Rx.txt" | grep -q .'; then
		execute_rsync "rsync -avz ${UNIT}:/OLMA/data/*SampleOptimiser_Rx.txt /var/OLMA/dak/"
	else
		echo -e "${COLOR_RED}No SampleOptimiser_Rx.txt file found on ${UNIT} ${COLOR_RESET}"
	fi

	# Check if the file exists
	echo -e "${COLOR_CYAN}Fetching all daily.csv files ${COLOR_RESET}"
	if ssh $UNIT 'find /OLMA/data -maxdepth 1 -type f -name "*db_data.csv" | grep -q .'; then
		# Extract the basename from the original file
		fileName=$(ssh $UNIT "basename /OLMA/data/*db_data.csv")
		# Rsync the temporary file over to the comms gateway
		execute_rsync "rsync -avz ${UNIT}:/OLMA/data/*db_data.csv /var/OLMA/dak/${fileName}.tmp"
		# Append the data from the temp file to the original file
		cat /var/OLMA/dak/${fileName}.tmp >> "/var/OLMA/dak/${fileName%.csv}_$(date +%Y%m%d-%H%M).csv"
		# Remove the remote file
		ssh ${UNIT} 'rm /OLMA/data/*db_data*.csv' 
		# Remove the temp file
		rm /var/OLMA/dak/${fileName}.tmp 
	else
		# If the file doesn't exist, print a message
		echo -e "${COLOR_RED}No db_data.csv file found on ${UNIT}. ${COLOR_RESET}"
	fi

	echo -e "${COLOR_CYAN}Fetching all .log files ${COLOR_RESET}"
	if ssh $UNIT 'find /OLMA/data -maxdepth 1 -type f -name "*.log" | grep -q .'; then
		# List remote log files
		remote_logs=($(ssh ${UNIT} 'ls /OLMA/data/*.log'))
		for remote_log in "${remote_logs[@]}"; do
			#Extract the filename from the path
			filename=$(basename "${remote_log}")

			echo -e "${COLOR_CYAN}Fetching ${filename} ${COLOR_RESET}"

			# Check if the filename already contains ${CLI}${UNIT}
			if [[ "${filename}" == "${CLI}${UNIT}_"* ]]; then
				# File already has the correct name, so rsync without renaming
				execute_rsync "rsync -avz ${UNIT}:${remote_log} /var/OLMA/dak/"
			else
				# Add ${CLI}${UNIT} to the front of the filename and then rsync
				new_filename="${CLI}${UNIT}_${filename}"
				execute_rsync "rsync -avz ${UNIT}:${remote_log} /var/OLMA/dak/${new_filename}"
			fi

			# Delete the original log file on the remote unit
			ssh ${UNIT} "rm ${remote_log}"
		done
	else
		echo -e "${COLOR_RED}No .log files found on ${UNIT} ${COLOR_RESET}"
	fi
done

echo -e "${COLOR_GREEN}Syncing ${COLOR_RESET}"
sync
