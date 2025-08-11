#!/bin/bash

VERSION=2.0

source /etc/bluecube/cgw.conf

clientName=$(hostname | cut -c 1-3)

serverUser="olma"
serverIP="46.235.226.48"
clientAreaFile="/home/olma/private/scripts/sync_time_clients.txt"

# SSH into the readings server and retrieve the client's timezone
clientArea=$(ssh "$serverUser@$serverIP" "sed -nE 's/^$clientName=(.*)/\1/p' \"$clientAreaFile\"")

echo "Client Timezone: $clientArea"

if [ -z "$clientArea" ]; then
    echo "Client timezone not found for $clientName on the readings server."
    exit 1
fi

# Fetch the current local time for the client's timezone from timeapi.io
apiResponse=$(ssh -t "$serverUser@$serverIP" "curl -s 'https://timeapi.io/api/Time/current/zone?timeZone=$clientArea'")

# Fix for HTTP status check
httpStatus=$(ssh -t "$serverUser@$serverIP" "curl -o /dev/null -s -w \"%{http_code}\" 'https://timeapi.io/api/Time/current/zone?timeZone=$clientArea'")

echo "API HTTP Status: $httpStatus"

if [ "$httpStatus" -eq 200 ]; then
    # Extract datetime using sed (without jq)
    datetime=$(echo "$apiResponse" | sed -n 's/.*"dateTime":"\([^"]*\)".*/\1/p' | cut -d '.' -f 1)

    echo "Extracted Datetime: $datetime"

    if [ -n "$datetime" ]; then
        dateComponent=$(echo "$datetime" | cut -d 'T' -f 1)
        timeComponent=$(echo "$datetime" | cut -d 'T' -f 2)

        for UNIT in "${MQI[@]}"
        do
            ssh "$UNIT" "date -s \"$dateComponent $timeComponent\""
            ssh "$UNIT" "hwclock --systohc"
            echo "Time synchronized successfully for $UNIT."
        done
    else
        echo "Failed to retrieve time data for $clientName."
    fi
else
    echo "API request for $clientArea returned a non-200 status code ($httpStatus). Not changing the time."
fi

