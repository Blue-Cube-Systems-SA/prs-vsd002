#!/bin/bash

VERSION=1.0.0
source /etc/bluecube/cgw.conf

serialnumber=${CLI}${CGW}
remoteserver1="78.47.153.238"
remoteserver2="fsn.bluecube.biz"
remoteuser="olma"

# loop for a long time (round robin servers)
while ((1))
do
    echo "get allocated port from server 1"
    remoteport=`ssh ${remoteuser}@${remoteserver1} '~/private/tunnel-getport '${serialnumber}`
    if [ ${remoteport} ]
    then
      echo "open tunnel 1"
      autossh -M 5${remoteport} -NCR ${remoteport}:127.0.0.1:22  ${remoteuser}@${remoteserver1}
    fi

  # keep it sane
  sleep 100

    echo "get allocated port from server 2"
    remoteport=`ssh ${remoteuser}@${remoteserver2} '~/private/tunnel-getport '${serialnumber}`
    if [ ${remoteport} ]
    then
      echo "open tunnel 2"
      autossh -M 5${remoteport} -NCR ${remoteport}:127.0.0.1:22  ${remoteuser}@${remoteserver1}
    fi
done
