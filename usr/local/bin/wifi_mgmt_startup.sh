#!/bin/bash

echo "Starting wifi_mgmt service"

while true; do
	wifi_mgmt start 0

	sleep 60
done
