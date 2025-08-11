#!/bin/bash

# DESCRIPTION:
# This Bash script monitors changes in a file named "newest.csv" and   
# calculates averages based on shift configurations specified in a     
# "shifts.conf" file. It sources configuration data from               
# "/etc/bluecube/mqi.conf" and performs data processing to append      
# information to shift-specific CSV files and calculate averages.       
#                                                                      
# The script includes functions such as "readData()", "sendAveToCSV()", 
# and "doAve()" to handle these tasks. It also checks if the            
# "CALCAVERAGES" setting in "mqi.conf" is enabled before proceeding.    
#
# USAGE:
#   - Ensure that shift times are filled in the "shifts.conf" file.
#   - The script checks if "newest.csv" has been updated, and if so, it adds
#     data to "averages.csv".
#   - When a shift ends, the script updates a shift CSV file.

VERSION=1.1.1

# Source configuration data (Check if Calcaverages is enabled)
source /etc/bluecube/mqi.conf

# Function to read data from newest.csv and append it to shift-specific CSV files
readData() {
    # echo "_______readData()_______"
    if [ "$(($OIindex-2))" -lt "$Comp" ]	# Check if OIindex is within range of Comp
    then
        # Append data to shift-specific CSV file, placing OI first
        echo `cut -d "," -f$OIindex ../OLMA/data/newest.csv`,`cut -d ',' -f 3-$(($OIindex-1)),$(($OIindex+1))-$(($Comp+2)) ../OLMA/data/newest.csv` >> ../OLMA/data/$NameOfShift.csv
        echo "NameOfShift= ${NameOfShift}"
        tail -n 1 /OLMA/data/"$NameOfShift".csv
    else
        # Append data to shift-specific CSV file without OI
        echo `cut -d "," -f$OIindex ../OLMA/data/newest.csv`,`cut -d ',' -f 3-$(($Comp+2)) ../OLMA/data/newest.csv` >> ../OLMA/data/$NameOfShift.csv
        echo "NameOfShift= ${NameOfShift}"
        tail -n 1 /OLMA/data/"$NameOfShift".csv 
    fi
}

# Function to calculate and send averages to an "averages" CSV file
sendAveToCSV() {
    # echo "_______sendAveToCSV()_______"
    if [ ! -e ../OLMA/data/`hostname`_averages_`date +%Y%m`.csv ] # Check if the "averages" CSV file exists
    then
        # Create the "averages" CSV file and add headers
        touch ../OLMA/data/`hostname`_averages_`date +%Y%m`.csv
        echo -n "Date,Shift," >> ../OLMA/data/`hostname`_averages_`date +%Y%m`.csv

        # Add mineral names as headers
        for (( MINERAL=1; MINERAL<$Comp; MINERAL+=1 ))
        do
            # Extract mineral names from training.conf
            echo -n `sed -ne '/ *\[ *Mineral Names *\]/,/^ *\[/p' /OLMA/conf/training.conf |grep "Mineral$MINERAL *=" |sed -e 's/^.*= *//' -e 's/ *$//'`',' >> ../OLMA/data/`hostname`_averages_`date +%Y%m`.csv
        done

        if [ "$(($OIindex-2))" -lt "$Comp" ]
        then
            # Add OI mineral name as the last header
            echo  `sed -ne '/ *\[ *Mineral Names *\]/,/^ *\[/p' /OLMA/conf/training.conf |grep "Mineral$Comp *=" |sed -e 's/^.*= *//' -e 's/ *$//'` >> ../OLMA/data/`hostname`_averages_`date +%Y%m`.csv
        else
            # Add OI mineral name as the last header
            echo  `sed -ne '/ *\[ *Mineral Names *\]/,/^ *\[/p' /OLMA/conf/training.conf |grep "Mineral$OIindex *=" |sed -e 's/^.*= *//' -e 's/ *$//'` >> ../OLMA/data/`hostname`_averages_`date +%Y%m`.csv
        fi
    fi

    # Create a timestamp for shift averages
    ShiftStamp="$(date +%Y/%m/%d\ %T --date=$ShiftEnd),$NameOfShift"

    # Append shift averages to "averages" CSV
    echo -n $ShiftStamp, >> ../OLMA/data/`hostname`_averages_`date +%Y%m`.csv

    # Calculate column-wise averages and append to "averages" CSV
    echo `awk -F ',' '$1<$OILevel { for (i = 1; i<=NF;i++) sum[i]+=$i; p++} END { for(i =1; i<=NF; i++) print sum[i]/p}' ../OLMA/data/$NameOfShift.csv`|sed 's/ /,/g'>> ../OLMA/data/Datastring.csv

    if [ "$(($OIindex-2))" -lt "$Comp" ]
    then
        # Append averages to "averages" CSV with OI
        echo `cut -d "," -f 2-$(($OIindex-2)) ../OLMA/data/Datastring.csv`,`cut -d ',' -f1 ../OLMA/data/Datastring.csv`,`cut -d "," -f $(($OIindex-1))- ../OLMA/data/Datastring.csv` >> ../OLMA/data/`hostname`_averages_`date +%Y%m`.csv
    else
        # Append averages to "averages" CSV without OI
        echo `cut -d "," -f 2-$(($OIindex-2)) ../OLMA/data/Datastring.csv`,`cut -d ',' -f1 ../OLMA/data/Datastring.csv` >> ../OLMA/data/`hostname`_averages_`date +%Y%m`.csv
    fi

    # Clean up temporary files
    rm ../OLMA/data/Datastring.csv
    rm ../OLMA/data/$NameOfShift.csv
}

# Function to calculate averages and process data based on shift configurations
doAve() {
    #    echo "_______doAve()_______"

    # Get timestamps from various sources:
    # Get timestamp of the first column (time) from newest.csv, and convert it to seconds since epoch
    let "fileT=`cut -d ',' -f1 ../OLMA/data/newest.csv|date +%s`"

    # Convert shift start and shift end times for today's date into epoch seconds
    shiftS=$(date +%s --date=$ShiftStart)  # Start of today's shift
    shiftE=$(date +%s --date=$ShiftEnd)    # End of today's shift

    # Special cases for overnight shifts: define the times for midnight and early morning
    NightTime=$(date +%s --date="00:00+1day")  # Midnight time for overnight shift handling
    MorningTime=$(date +%s --date="00:00")     # Early morning start time

    # Check if the shift is an overnight shift (flag is set to 1)
    if [ "$Overnightflag" == 1 ]  # Overnight shift check
    then
        # echo "Processing overnight shift"

        # First time window: from the start of the shift until midnight
        if [ "$fileT" -ge "$shiftS" ]  # If the timestamp of newest.csv is after the shift start
        then
            if [ "$fileT" -lt "$NightTime" ]  # Before midnight
            then
                echo "Between start of shift ($ShiftStart) and midnight (00:00)"
                readData  # Read and process data during this time window
            fi
        # Second time window: from midnight until the end of the shift
        elif [ "$fileT" -ge "$MorningTime" ]  # If the timestamp is after midnight
        then
            if [ "$fileT" -lt "$shiftE" ]  # Before the end of the shift
            then
                echo "Between midnight (00:00) and end of shift ($ShiftEnd)"
                readData  # Read and process data during this time window
            fi

            # If the time exceeds the end of the shift, finalize the shift data
            if [ "$fileT" -ge "$shiftE" ]  # After the end of the shift
            then
                # Between ShiftEnd and ShiftStart. Just finalize date and wait for next shift to start
                echo "Shift ended, finalizing shift data (between shift end and shift start)"
                if [ -e ../OLMA/data/$NameOfShift.csv ]  # If the shift-specific CSV exists
                then
                    sendAveToCSV  # Calculate averages and write to CSV
                fi
            fi
        fi
    else
        # echo "Processing regular shift (non-overnight)"

        # For regular shifts, check if within the shift time
        if [ "$fileT" -ge "$shiftS" ]  # If the timestamp of newest.csv is after the shift start
        then
            if [ "$fileT" -lt "$shiftE" ]  # Before the shift end
            then
                echo "Between start of shift ($ShiftStart) and end of shift ($ShiftEnd)"
                readData  # Read and process data during this time window
            fi
        fi

        # If the time is after the end of the shift, finalize the shift data
        if [ "$fileT" -ge "$shiftE" ]  # After the end of the shift
        then
            if [ -e ../OLMA/data/$NameOfShift.csv ]  # If the shift-specific CSV exists
            then
                # Between ShiftEnd and ShiftStart. Just finalize date and wait for next shift to start
                echo "Shift ended, finalizing shift data (between shift end and shift start)"
                sendAveToCSV  # Calculate averages and write to CSV
            fi
        fi
    fi
}


echo "Starting Calcaverages.sh"
echo "."

# Get the mineral number of OI in training.conf
OIindex=`grep "OI" /OLMA/conf/training.conf | sed 's/Mineral//g' | sed 's/=OI//g'` #typically number 4
OIindex=$(($OIindex+2)) # 2 added due to columns

# Touch the "averages" file for the current month if it doesn't exist
touch ../OLMA/data/previoustime;

# Infinite loop to monitor changes in newest.csv and calculate averages
while [ 1 ];
do
	# Check if calcaverages is enabled in mqi.conf
    if [ "$CALCAVERAGES" -gt 0 ];
    then
        # Check if newest.csv has been updated
        if [ ../OLMA/data/newest.csv -nt ../OLMA/data/previoustime ];   # True if newest.csv changed more recently than previoustime
        then
            # echo "newest.csv has been updated since previous time"
            
            # Update previoustime for future checking
            touch ../OLMA/data/previoustime;

            # Read shift configurations from shifts.conf and process data
            while read LINE; # Read each shift line description in shifts.conf
            do
                NameOfShift=$(cut -d ',' -f 1 <<< $LINE);		# Used to indentify current shift name and used in naming .csv files
                ShiftStart=$(cut -d ',' -f 2 <<< $LINE);		# Used to determine whether the current time is within the shift's time range.
                ShiftEnd=$(cut -d ',' -f 3 <<< $LINE);			# Used in combination with ShiftStart to check if the current time is within the shift's time range.
                OILevel=$(cut -d ',' -f 4 <<< $LINE);
                Comp=$(cut -d ',' -f 5 <<< $LINE);				# Amount of minerals specified in training.conf (that will be written to averages.csv)
                Overnightflag=$(cut -d ',' -f 6 <<< $LINE);		# Used if start and end time of shift run over 00h00 (e.g Start 22:00, End 06:00)
                doAve
            done < /OLMA/scripts/shifts.conf			

            echo "."
        fi
    else
		echo "CALCAVERAGES not enabled in /etc/bluecube/mqi.conf"
	fi

	# Wait 1 second before trying again
    sleep 1
done
