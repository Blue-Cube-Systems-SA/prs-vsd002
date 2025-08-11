#!/bin/bash
if [ -d "/OLMA/OLMA-A/" ]   # Test if  machine is mutiplex
then
    rm /OLMA/OLMA-A/input/bucket_present.flag
    rm /OLMA/OLMA-B/input/bucket_present.flag
else
    rm /OLMA/input/bucket_present.flag
fi
