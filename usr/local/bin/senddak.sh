#!/bin/bash

# This script sends .dak files, .log files, .csv files etc. to Readings

VERSION=1.1.7-arm

source /etc/bluecube/cgw.conf
source /etc/bluecube/servers.conf
source /etc/bluecube/terminal_colours.conf
source /etc/bluecube/mqi.conf

lockFile="/OLMA/input/senddak.lock"
logFile="/OLMA/data/senddak.log"

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
        if [ $lock_age -ge $senddakLockFileMaxAgeMin ]; then
            echo -e "${COLOR_RED}Lock file was more than $senddakLockFileMaxAgeMin minutes old ($lock_age minutes old). Removing.${COLOR_RESET}"
            log "Lock file was more than $senddakLockFileMaxAgeMin minutes old ($lock_age minutes old). Removing."

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

echo -e "${COLOR_GREEN}Rsync ${CLI}.emergency.sh from Readings and execute ${COLOR_RESET}"
execute_rsync "rsync -avz $olmaUser@$readingsIP:~/updates/${CLI}.emergency.sh /var/OLMA/updates/"
/var/OLMA/updates/${CLI}.emergency.sh

echo -e "${COLOR_GREEN}Rsync all .dak files to Readings ${COLOR_RESET}"
execute_rsync "rsync -avz /var/OLMA/dak/*.dak $olmaUser@$readingsIP:~/dak/"

echo -e "${COLOR_GREEN}Rsync all .csv (except *db_data*.csv) files to Readings ${COLOR_RESET}"
execute_rsync "rsync -avz --exclude '*db_data*.csv' /var/OLMA/dak/*.csv $olmaUser@$readingsIP:~/dak/"

# Send CSV files to Readings and delete some of them if rsync is successful
echo -e "${COLOR_GREEN}Rsync all db_data.csv files to Readings ${COLOR_RESET}"
if execute_rsync "rsync -avz /var/OLMA/dak/*db_data*.csv $olmaUser@$readingsIP:~/dak/"; then
    # If rsync was successful, delete the source files
    rm -f /var/OLMA/dak/*db_data*.csv
fi

echo -e "${COLOR_GREEN}Rsync SampleOptimiser_Rx.txt files to Readings ${COLOR_RESET}"
execute_rsync "rsync -avz /var/OLMA/dak/*SampleOptimiser_Rx.txt $olmaUser@$readingsIP:~/dak/"

echo -e "${COLOR_GREEN}Rsync ${CLI} updates files from Readings to Gateway ${COLOR_RESET}"
execute_rsync "rsync -avz $olmaUser@$readingsIP:~/updates/*${CLI}* /var/OLMA/updates/"

# Loop through all the MQis
for UNIT in "${MQI[@]}"
do 
    echo -e "${COLOR_GREEN}SSH into ${UNIT} ${COLOR_RESET}"

    echo -e "${COLOR_GREEN}Add ${UNIT} .dak files from ${CLI}.dakFiles_Rx.txt to ${CLI}.${UNIT}.deleteme.txt ${COLOR_RESET}"
    grep "${UNIT}" /var/OLMA/updates/${CLI}.dakFiles_Rx.txt > /var/OLMA/updates/${CLI}.${UNIT}.deleteme.txt

	echo -e "${COLOR_GREEN}Run distr_updates.sh locally ${COLOR_RESET}"
	/usr/local/bin/distr_updates.sh

	echo -e "${COLOR_GREEN}Run del-dak-Tx.sh on ${UNIT} ${COLOR_RESET}"
	ssh ${UNIT} /usr/local/bin/del-dak-Tx.sh

	echo -e "${COLOR_GREEN}Run del-dak-Tx.sh locally ${COLOR_RESET}"
	/usr/local/bin/del-dak-Tx.sh

    echo -e "${COLOR_GREEN}Rsync and append .log files to .log files on Readings ${COLOR_RESET}"
    # Loop through all the log files on the unit and send to readings
    for log_file in /var/OLMA/dak/*.log; do
        fileBaseName=$(basename "${log_file}")

		# Append the contents of the local log file to the end of the readings log file
		cat ${log_file} | ssh "$olmaUser@$readingsIP" "cat >> ~/dak/${fileBaseName}"
		# Remove the local log file
		rm ${log_file}
    done
done
