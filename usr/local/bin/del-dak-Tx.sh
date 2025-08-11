#!/bin/bash
VERSION="1.0.1"
# Deletes dak-files in /OLMA/data that was successfully transmitted to homebase

for abc in `cat /var/OLMA/updates/*.deleteme.txt`
do
  if [ -e "/OLMA/data/$abc" ]
  then
    echo
    echo $abc
    rm "/OLMA/data/$abc"
  else
    echo -n "."
  fi

  if [ -f "/etc/bluecube/cgw.conf" ] 
  then
    if [ -e "/var/OLMA/dak/$abc" ]
    then
      echo
      echo $abc
      rm "/var/OLMA/dak/$abc"
    else
      echo -n "."
    fi
  fi
done
echo
