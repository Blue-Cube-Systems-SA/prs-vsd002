#!/bin/bash

# This script monitors the system resources and performs checks

VERSION="1.3-arm"

source /etc/bluecube/mqi.conf
source /etc/bluecube/terminal_colours.conf

# =========== FUNCTIONS ===========

# Function to retrieve machine variables
get_machine_specs() {
    # Memory information
    mem_total=$(free | tr -s ' ' | awk '/^Mem/ {print $2}')
    mem_free=$(free | tr -s ' ' | awk '/^Mem/ {print $4}')
    
    # Filesystem storage information
    fs_total=$(df | awk '/\/dev\/mmcblk0p3/ {print $2}')
    fs_free=$(df | awk '/\/dev\/mmcblk0p3/ {print $4}')
    
    # Heater memory percentage
    heater_mem_perc=$(ps aux | grep heater | grep -v "grep" | sort -r -k4 | head -1 | awk '{print int($4)}')
}

# Function to log messages with timestamp
log_message() {
    local message="$1"
    local log_file="/OLMA/data/checkmem.log"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] ${message}" >> "${log_file}"
}

# Function to get the actual size of a file in bytes
get_file_size() {
    stat -c %s "$1"
}

# Function to convert bytes to megabytes
bytes_to_megabytes() {
    echo "$(( $1 / (1024 * 1024) ))"
}

# Function to calculate the percentage
calculate_percentage() {
    local total=$1
    local free=$2
    echo "$(( free * 100 / total ))"
}

# Function to check memory and reboot if necessary
check_memory() {
	# Check if the amount of free memory is lower than the dangerously low setting
    if [[ $mem_free -lt $DANG_LOW_MEM_WARNING ]]; then
        echo -e "${COLOR_RED}Memory is critically low (${mem_free} kB < ${DANG_LOW_MEM_WARNING} kB). Rebooting the system.${COLOR_RESET}"
        log_message "Memory is critically low (${mem_free} kB < ${DANG_LOW_MEM_WARNING} kB). Rebooting the system."
        reboot
    else
        echo -e "${COLOR_GREEN}Memory is within acceptable limits (${mem_free} kB >= ${DANG_LOW_MEM_WARNING} kB). Not rebooting.${COLOR_RESET}"
    fi
}

# Function to check filesystem storage and delete large files if necessary
check_filesystem() {
    local fs_perc_left=$(calculate_percentage "$fs_total" "$fs_free")
    
	# Enable dotglob option to include hidden files
	shopt -s dotglob

	# Check if the amount of free storage is lower than the dangerously low setting
    if [[ $fs_perc_left -le $DANG_LOW_FS_PERC ]]; then
        echo -e "${COLOR_RED}Percentage of available storage is critically low (${fs_perc_left}% <= ${DANG_LOW_FS_PERC}%). Deleting all files bigger than ${DELETE_FILE_SIZE}MB.${COLOR_RESET}"
        log_message "Percentage of available storage is critically low (${fs_perc_left}% <= ${DANG_LOW_FS_PERC}%). Deleting all files bigger than ${DELETE_FILE_SIZE}MB."

        # Check files in /OLMA/data and if their size is larger than the setting
		# so that they can be deleted to free up some storage on the unit
        for file in /OLMA/data/*; do
            file_size_bytes=$(get_file_size "$file")
            file_size_mb=$(bytes_to_megabytes "$file_size_bytes")
			# Check if the file's size is larger than the specified setting
            if [ "$file_size_mb" -ge "$DELETE_FILE_SIZE" ]; then
                echo -e "${COLOR_RED}Deleting $file ${COLOR_RESET}"
				log_message "Deleting $file"
				rm $file
            fi
        done

		# If the unit is a comms gateway, check the files in /var/OLMA/dak and if their size is larger than the setting
		# so that they can be deleted to free up some storage on the unit
        if { [ -n "$IS_CGW" ] && [ "$IS_CGW" -eq 1 ]; } || [ -d "/var/OLMA/dak/" ]; then
			for file in /var/OLMA/dak/*; do
				file_size_bytes=$(get_file_size "$file")
				file_size_mb=$(bytes_to_megabytes "$file_size_bytes")
				# Check if the file's size is larger than the specified setting
				if [ "$file_size_mb" -ge "$DELETE_FILE_SIZE" ]; then
					echo -e "${COLOR_RED}Deleting $file ${COLOR_RESET}"
					log_message "Deleting $file"
					rm $file
				fi
			done
		fi
    else
        echo -e "${COLOR_GREEN}Percentage of available storage is within acceptable limits (${fs_perc_left}% > ${DANG_LOW_FS_PERC}%). Not deleting files.${COLOR_RESET}"
    fi

	# Disable dotglob option to revert to the default behavior
	shopt -u dotglob
}

# Function to check heater memory usage and restart if necessary
check_heater_memory() {
	# Check if heater is using more memory than allowed
    if [[ $heater_mem_perc -gt $HEATER_MEM_LIMIT ]]; then
        echo -e "${COLOR_RED}Heater memory percentage outside of acceptable limit (${heater_mem_perc}% >= ${HEATER_MEM_LIMIT}%). Restarting heater.${COLOR_RESET}"
        log_message "Heater memory percentage outside of acceptable limit (${heater_mem_perc}% >= ${HEATER_MEM_LIMIT}%). Restarting heater."
        killall heater
        systemctl restart heater
    else 
        echo -e "${COLOR_GREEN}Heater memory consumption within acceptable range (${heater_mem_perc}% < ${HEATER_MEM_LIMIT}%). Not restarting heater.${COLOR_RESET}"
    fi
}

# =========== MAIN CODE ===========

# Retrieve machine specifications
get_machine_specs

# Check memory and reboot if necessary
check_memory

# Check filesystem and delete large files if necessary
check_filesystem

# Check heater memory usage and restart if necessary
check_heater_memory

