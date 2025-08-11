#!/bin/bash

VERSION=1.2.1-arm

# Program that takes a time window in which a sample must be taken.
# A random time within that window will be selected and from that point on a sample can be taken.
# The program checks sensor reading limits to determine if the machine is within certain limits to take a sample.
# If the program never deems the machine ready to take a sample (because it is outside of the limits),
# then at the end of the window it will still instruct the machine to take a sample regardless of the limits.
# This is so that a sample is taken at least once per window even if conditions are not met.

# Usage: ./bucket_robot.sh  Window  Base_OLMA_directory

# Define file paths and script variables
BTOSEND_SCRIPT=/usr/local/bin/trendline.sh
BCONF=conf/bucket_conf.csv                              # Configuration file where sampling conditions are set out
BFLAGDIR=input
BTAKESAMPLE_SCRIPT=scripts/green.sh                     # Script that instructs the machine to take a sample
BOUTPUTFILE=data/bucket_robot.out


# Get input arguments
WINDOW=$1                                               # Time window in which the unit must take a sample
OLMA=$2                                                 # The OLMA directory of the unit (e.g. /OLMA/, /OLMA/OLMA-A/ and /OLMA/OLMA-B/)
UNIT=Foundry
TOSEND_SCRIPT="$BTOSEND_SCRIPT $OLMA/"
CONF=$OLMA/$BCONF
FLAGDIR=$OLMA/$BFLAGDIR
TAKESAMPLE_SCRIPT=$OLMA/$BTAKESAMPLE_SCRIPT
TAKESAMPLEBIT_FLAG=/OLMA/input/autoSampleBit.flag       # Flag that will set mqi_status_byte's sampling bit high
OUTPUTFILE=$OLMA/$BOUTPUTFILE
BATTEMPTSAMPLEFILE=/OLMA/data/bucket_beginSampleTime    # This file contains the time to begin attempting to sample

echo $OLMA
echo '============'
echo 'WINDOW, TOSEND_SCRIPT, CONF, FLAGDIR, TAKESAMPLE_SCRIPT, OUTPUTFILE'
echo "$WINDOW, $TOSEND_SCRIPT, $CONF, $FLAGDIR, $TAKESAMPLE_SCRIPT, $OUTPUTFILE"

if [[ ! -f $OUTPUTFILE ]]; then echo ' ' > $OUTPUTFILE; fi

# Read values from the configuration file into variables
read NAM MI1 MI2 MI3 MA3 MA2 MA1 DUM <<< $(grep "^ *InBuckt"[' ',$'\t'] $CONF | tail -n1)
#Name -LastHr -Outlie Min Max +Outlie +LastHr Comments


if [[ -f $FLAGDIR/bucket_present.flag ]]
then
    # If there is at least one sample in the bucket
    if [[ -f $FLAGDIR/bucket_samples.num ]]
    then
        # Read how many samples we have in the bucket
        read InBuckt < $FLAGDIR/bucket_samples.num

        # If the file exists and is empty, assume that 1 sample is in the bucket
        if [[ $InBuckt = '' ]]; then InBuckt=1; fi

        # Check the configuration file to see if we have more or less samples in the bucket than we want
        # If the window to take a sample has not passed
        if [[ $WINDOW -ge 0 ]]; then # During normal hours
            if [[ $MI3 != X && $MI3 != x &&  $InBuckt -lt $MI3 ]]; then 
                RESULT='_' #Bucket too empty (for completeness only)
            elif [[ $MA3 != X && $MA3 != x &&  $InBuckt -gt $MA3 ]]; then 
                RESULT='[' #Bucket too full
            else 
                RESULT='|' #Bucket ready for sample
            fi
        fi
    else
        # If the file is not present, assume no samples are in the bucket
        InBuckt=0
        RESULT='|' #Bucket ready and empty
    fi
else
    InBuckt=-1
    RESULT='X' #Bucket not ready
fi

# Output bucket status and configuration variables
echo $InBuckt $NAM $MI1 $MI2 $MI3 $MA3 $MA2 $MA1 $DUM

# Define process variables to check
CHECKS=(TOffset Energy Density Flow Intens Unknown OI Stabil ${UNIT}PumpStatus)

# Loop through the process variables
for CHECK in ${CHECKS[*]}
do
    # Read the limits for the current variable from the conf file
    LIM=$(grep "^ *${CHECK}"[' ',$'\t'] $CONF |tail -n1)

    # Determine the column number for the variable in the trend file
    let C=`$TOSEND_SCRIPT Fieldnames 2>/dev/null |sed -e "s/$CHECK.*//" |awk -F, '{print NF}'`

    # Get the current value for the variable
    VAL=`$TOSEND_SCRIPT 2>/dev/null |cut -d, -f$C-$C |sed 's/ //g'`
    if [[ "${VAL}" = "" ]]; then VAL=0; fi

    # Determine the upper and lower bounds for the variable
    HI=$(echo ${CHECK:0:1})           # First letter of the current sensor reading (e.g if Temperature then HI = T)
    LO=$(echo $HI |tr 'A-Z' 'a-z')    # Change the first letter of the sensor reading to a small letter (e.g. HI = T, then LO = t)
    echo $HI $LO $VAL $LIM

    # If the window to take a sample has not passed
    if [[ $WINDOW -ge 0 ]]; then # During normal hours
        RESULT=$RESULT$(echo $LO $HI $VAL $LIM \
          |awk '{ print ($7!="X" && $7!="x" && $3<$7) ? $1 : ($8!="X" && $8!="x" && $3>$8) ? $2 : "."}')
        #  $3:VAL  $7:Min  $8:Max
    fi

done

# Check if the file containing the time to begin attempting to sample exists
if [ -f "$BATTEMPTSAMPLEFILE" ]
then
    beginTrying=$(<$BATTEMPTSAMPLEFILE);
else
    # Generate a random sample time if the file is not present
    beginTrying=$(( $RANDOM % $WINDOW + 1 ))
    # Store the random sample time in a file for this shift
    echo "$beginTrying" > $BATTEMPTSAMPLEFILE; # Store the random sample time in a file for this shift
    echo $(( $WINDOW-$beginTrying )) minutes before trying to sample
fi

# Determine if it's time to attempt a sample based on the window
if [ $WINDOW -le $beginTrying ]
then
    RESULT=${RESULT}1
else
    RESULT=${RESULT}0
fi

# Output the final result
echo $RESULT
echo $RESULT >${OUTPUTFILE}.tmp; mv ${OUTPUTFILE}.tmp ${OUTPUTFILE}

# If it's time to attempt a sample and the conditions are met
if [ $WINDOW -le $beginTrying ]
then
    # If all conditions are met or the window has passed (and the bucket is ready), take a sample
    if [[ $RESULT == '|.........1' || ($WINDOW -lt 0 && ${RESULT:0:1} == '|') ]]
    then
        echo "Instructing mqsembed to take a sample"
        # Instruct mqsembed to take a sample by running the sample script
        $TAKESAMPLE_SCRIPT
        # Touch a flag file to indicate a sample was taken (used in the mqi_status_byte file)
        touch $TAKESAMPLEBIT_FLAG
        # Indicate that a sample was taken using sample optimiser to prevent another samples from being taken in the same window
        echo 1 > $FLAGDIR/bucket_samples.num
        # Save the current time to a text file indicating the time that a sample optimiser .dak file was created
        echo `hostname`_`date +%Y%m%d`-`date +%H%M`.dak >> /OLMA/data/`hostname`_SampleOptimiser_Rx.txt
    else
        echo "Not instructing mqsembed to take a sample"
    fi
fi
