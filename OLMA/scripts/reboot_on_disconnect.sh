#!/bin/bash

if cell_mgmt status | grep -c "Status: connected"; then
   echo "Cell Network Connected $(date +'%T %d/%m/%Y')" >> /OLMA/scripts/connection.log

else
   echo "Cell Network Disconnected: rebooting now $(date +'%T %d/%m/%Y')" >> /OLMA/scripts/connection.log
   reboot

fi
