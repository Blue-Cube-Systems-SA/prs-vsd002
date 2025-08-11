#!/bin/bash

VERSION=1.1-arm

source /etc/bluecube/mqi.conf
source /etc/bluecube/servers.conf
source /etc/bluecube/terminal_colours.conf

# Constants
nth_minute=5  # Interval to run the main loop
start_monitor_file=/OLMA/input/network_ready.flag
stop_monitor_file=/OLMA/input/network_not_ready.flag
reboot_log_file=/OLMA/data/cellReboots.log
error_log_file=/OLMA/data/cellErrors.log

# Variables
retries=0
monitor_flag=1

# Function to log messages to the specified log file
log() {
    local logfile=$1
    local message=$2
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $message" >> "$logfile"
}

# Function to monitor network readiness
monitor_network() {
    while [ $monitor_flag -eq 0 ]; do
        if [ -f $start_monitor_file ]; then
            rm $start_monitor_file
            monitor_flag=1
        fi
        if [ -f $stop_monitor_file ]; then
            rm $stop_monitor_file
        fi
        echo -e "${COLOR_CYAN}Waiting for network ready flag${COLOR_RESET}"
        sleep 3
    done
}

# Function to check SIM card connection and manage retries
check_sim_connection() {
    retries=$((retries + 1))		# Incremement the number of retries to establish SIM connection
    reboot=0						# Variable to determine if the unit will be rebooted or not

	# Check if the SIM card is connected or not
    if [[ $(cell_mgmt status | grep -c "Status: connected") -gt 0 ]]; then
		# Try to SSH into Readings
        if ssh -c aes128-cbc ${olmaUser}@${readingsIP} 'echo'; then
            echo -e "${COLOR_GREEN}Successful SSH connection to Readings server${COLOR_RESET}"

			# Reset the retries and reboot variable as the unit has established a successful connection to readings
            retries=0
            reboot=0
        else
            reboot=1
        fi
    else
        reboot=1
    fi

    handle_restart $reboot
}

# Function to handle restart and logging
handle_restart() {
    local reboot=$1

	# If the unit was signalled to reboot
    if [ $reboot -eq 1 ]; then
		# If more the 5 retries have been done and still no successful SIM connection was estbalished, reboot the unit
        if [ $retries -ge 5 ]; then
            log $reboot_log_file "Moxa reboot ($retries)"
            reboot
        else
            log_connection_error
            restart_services
        fi
    fi
}

# Function to log connection errors
log_connection_error() {
	echo -e "${COLOR_RED}Unsuccessful connection to Readings server${COLOR_RESET}"
	echo -e "${COLOR_RED}Reboot retries: $retries ${COLOR_RESET}"
	log $reboot_log_file "Cell modem reboot ($retries)"

    log $error_log_file "Reboot retries: $retries"
    ssh -c aes128-cbc ${olmaUser}@${readingsIP} 'echo'
    exit_code=$?
    log $error_log_file "SSH into Readings exit code: ${exit_code}"
    log $error_log_file "Ping response: $(ping -c3 ${readingsIP})"
    log $error_log_file "Cell management status: $(cell_mgmt status)"
    log $error_log_file "SIM status: $(cell_mgmt sim_status)"
    log $error_log_file "Operator: $(cell_mgmt operator)"
    log $error_log_file "Module info: $(cell_mgmt module_info)"
}

# Function to restart necessary services
restart_services() {
	echo -e "${COLOR_CYAN}Restarting dhclient and tunnel2.service${COLOR_RESET}"
    killall dhclient
    systemctl restart tunnel2.service
}

# Main loop
while true; do
    monitor_network

    if [ -f $stop_monitor_file ]; then
        rm $stop_monitor_file
        monitor_flag=0
    fi

    # Check SIM card connection if using cellular
    if [ $USES_CELL -eq 1 ]; then
        check_sim_connection
    else
		echo -e "${COLOR_RED}The unit is not configured to use CELL${COLOR_RESET}"
	fi

    # Wait before the next iteration
    sleep 30
    while [ $(echo $(date +%M)%$nth_minute | bc) -gt 0 ]; do
        sleep 30
    done
done
