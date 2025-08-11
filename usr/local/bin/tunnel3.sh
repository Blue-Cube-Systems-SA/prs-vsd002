#!/bin/bash

VERSION=1.0.0
source /etc/bluecube/cgw.conf

serialnumber=${CLI}${CGW}
remoteserver1="182.160.154.41"
remoteserver2="syd.bluecube.biz"
remoteuser="olma"

# loop for a long time (round robin servers)
while ((1))
do
  if [ -a /var/lock/tunnel ]
  then
    echo "get allocated port from server 1"
    remoteport=`ssh -c aes128-cbc  ${remoteuser}@${remoteserver1} '~/private/tunnel-getport '${serialnumber}`
    if [ ${remoteport} ]
    then
      echo "open tunnel 1"
      autossh -M 2${remoteport} -NCR ${remoteport}:127.0.0.1:22  ${remoteuser}@${remoteserver1}
    fi
  fi

  # keep it sane
  sleep 100

  if [ -a /var/lock/tunnel ]
  then
    echo "get allocated port from server 2"
    remoteport=`ssh -c aes128-cbc ${remoteuser}@${remoteserver2} '~/private/tunnel-getport '${serialnumber}`
    if [ ${remoteport} ]
    then
      echo "open tunnel 2"
      autossh -M 2${remoteport} -NCR ${remoteport}:127.0.0.1:22  ${remoteuser}@${remoteserver1}
    fi
  fi
done
