#!/bin/bash

# The point of this script is to sycn the time on the machine with the current time of the client using the Readings server.
# It will fetch the timezone corresponding to client from a text file on Readings.
# Then it will get time using an API on readings
# The time will be sent back to the MQi and its time will be updated.

VERSION=1.0

source /etc/bluecube/cgw.conf

# Get the clientName from the first 3 characters of the hostname
clientName=$(hostname | cut -c 1-3)

# Define the readings server SSH details
serverUser="olma"
serverIP="46.235.226.48"
# File that stores all the clients and their timezones
clientAreaFile="/home/olma/private/scripts/sync_time_clients.txt"

# SSH into the readings server and retrieve the client's timezone
clientArea=$(ssh "$serverUser@$serverIP" "sed -nE 's/^$clientName=(.*)/\\1/p' \"$clientAreaFile\"")
#echo "clientArea = $clientArea"

if [ -z "$clientArea" ]; then
    echo "Client timezone not found for $clientName on the readings server."
    exit 1
fi

# Fetch the current local time for the client's timezone from worldtimeapi.org
apiReponse=$(ssh "$serverUser@$serverIP" "curl -s \"http://worldtimeapi.org/api/timezone/$clientArea\"")

# Add this debug line to check the HTTP response code
httpStatus=$(ssh "$serverUser@$serverIP" "curl -s -o /dev/null -w '%{http_code}' \"http://worldtimeapi.org/api/timezone/$clientArea\"")

# Only set the time if a positive HTTP status is returned (200)
if [ "$httpStatus" -eq 200 ]; then
    # Extract the datetime from the API response
    datetime=$(echo "$apiReponse" | grep -oP 'datetime":"\K[^"]+' | head -n 1)
    # echo "datetime = $datetime"

    # Break the datetime up into a date part and a time part
    dateComponent=$(echo "$datetime" | cut -d 'T' -f 1)
    timeComponent=$(echo "$datetime" | cut -d 'T' -f 2 | cut -d '+' -f 1)

    # If the date is valid, change the time
    if [ -n "$datetime" ]; then
	# Log into each unit and change their timezone to the client's timezone
	for UNIT in "${MQI[@]}"
        do
	    # SSH into the unit and set the system date and time to the unit's timezone
	    ssh "$UNIT" "date -s \"$dateComponent $timeComponent\""

	    # SSH into the unit and sync the hardware clock with the system time
            ssh "$UNIT" "hwclock --systohc"

	    echo "Time synchronized successfully for $UNIT."

	done
    else
        echo "Failed to retrieve time data for $clientName."
    fi
else
    echo "API request for $clientArea returned a non-200 status code. Not changing the time."
fi
