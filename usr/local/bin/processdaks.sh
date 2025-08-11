#!/bin/bash
VERSION="1.0.1"

CLIENT=`hostname`
#COMPONENTS=`grep MineralCount /OLMA/conf/training.conf | sed 's/MineralCount=//g'`
COMPONENTS=7

for DAKS in `ls -1 /OLMA/data/*.dak | grep -v luxcomp 2>/dev/null`; do
  echo -n ". "
  NEWONE=`grep  $DAKS  /OLMA/data/processed.txt`
  if [ -z "$NEWONE"  ]; then
    echo "$DAKS is not in the list."
    echo -n "$DAKS," >> /OLMA/data/${CLIENT}_sample_averages.csv
    rm /OLMA/data/apspec.csv
    rm /OLMA/data/pspec.csv
    rm /OLMA/data/rspec.csv
    cd /OLMA/
    ./mq200embed --preprocess $DAKS
    /OLMA/mqProcDak ${COMPONENTS} /OLMA/data/apspec.csv >> /OLMA/data/${CLIENT}_sample_averages.csv
    echo $DAKS >> /OLMA/data/processed.txt
    rm /OLMA/data/apspec.csv
    rm /OLMA/data/pspec.csv
    rm /OLMA/data/rspec.csv
  fi
done

#rsync -vcaue ssh  mq9:/OLMA/data/*sample_averages.csv /mnt/ramdisk/dak/
# */1  *    *     *      *   root  /usr/local/bin/processdaks.sh
