#!/bin/bash

SIM_PIN=9779
needs_pin=0
needs_apn=0

echo "Sleeping for a while to let modem start up properly"
sleep 180
echo "Checking if already attached to network"
if [ $(cell_mgmt attach_status | grep -c "PS: attached") -eq 0 ]
then
	echo "Not attached -> Power OFF Cell... sleeping for a while"
	cell_mgmt power_off
	sleep 60
	echo "Power ON Cell"
	cell_mgmt power_on
	echo "Waiting for things to settle"
	sleep 60
	if [ $needs_apn -eq 1 ]
	then
		echo "Set APN"
		cell_mgmt set_apn connect
		sleep 10
	fi
	if [ $needs_pin -eq 1 ]
	then
		echo "Unlock pin"
		cell_mgmt unlock_pin $SIM_PIN
		sleep 10
	fi
	tries=0
	echo "Checking if attached to the network"
	while [[ $(cell_mgmt attach_status | grep -c "PS: attached") -eq 0 && $tries -lt 10 ]]
	do	
		echo "Not attached... waiting and retrying"
		sleep 60
		tries=$(( tries+1 ))
	done	
	echo "Finished checking if attached to network... pausing for a while"
	sleep 5
fi

echo "Starting Cell"

tries=0
cell_mgmt_status=0
while [[ $cell_mgmt_status -eq 0 && $tries -lt 4 ]]
do
	cell_mgmt start
	echo "Waiting to connect"
	sleep 15
	if cell_mgmt status | grep -c "Status: connected"; then
		cell_mgmt_status=1
		echo "Success! Connected to mobile network"
	else
		cell_mgmt_status=0
		echo "Failed to connect to network. Waiting and retrying..."
		sleep 30
	fi
	tries=$(( tries+1 ))
done
