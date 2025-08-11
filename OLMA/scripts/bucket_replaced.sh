#!/bin/bash
VERSION=1.0.1
if [ -d "/OLMA/OLMA-A/" ]   # Test if  machine is mutiplex
then
    rm /OLMA/OLMA-A/input/bucket_samples.num
    rm /OLMA/OLMA-B/input/bucket_samples.num
    rm /OLMA/data/bucket_beginSampleTime
    touch /OLMA/OLMA-A/input/bucket_present.flag
    touch /OLMA/OLMA-B/input/bucket_present.flag
    sleep 60
else
    rm /OLMA/input/bucket_samples.num
    rm /OLMA/data/bucket_beginSampleTime
    touch /OLMA/input/bucket_present.flag
    sleep 60
fi
