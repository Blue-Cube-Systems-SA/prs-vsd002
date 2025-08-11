#!/bin/bash

# This script creates a csv file with column headers and overall MQi data
# The data will later be sent to a database and the column headers will be used to identify the columns
# It is therefore imperative that the column headers match output names in the SQL database 

VERSION=1.1.1-arm

# Define the header array
headerArray=(
"Date-and-Time"
"Analyser"
"Energy"
"Raw-Temperature"
"Calculated-Temperature"
"Bucket-Robot-Results"
"Status-Byte"
"Flash-Delay"
"Loadcell-Weight"
"Sample-Cabinet-Door"
"Free-Memory"
"Free-Root"
"Free-Overlay"
"Uptime"
"mqsembed-Running"
"mq200embed-Running"
"getspec-Running"
)


# Files involved in this script
databaseFile="/OLMA/data/`hostname`_db_data.csv"		# Where the trend data is written
energyFile="/OLMA/data/energy_newest.csv"
sensorFile="/OLMA/data/sensor.csv"
bucketRobotFile="/OLMA/data/bucket_robot.out"
statusByteFile="/OLMA/data/mqi_status_byte"
mq200ConfFile="/OLMA/mq200.conf"
sampleCabinetFile="/OLMA/data/samplecabinet.csv"
trainingConfFile="/OLMA/conf/training.conf"
newestFile="/OLMA/data/newest.csv"

# Global variables
dataColumnCount=0
defaultValue=""

# =============== FUNCTIONS ===============

# Function to check if the header and data array sizes match
checkColumnCount() {
    # Get the size of the data array (number of columns)
    dataColumnCount=$(echo "$dataString" | tr -cd ',' | wc -c)
    # Add 1 to account for the first column
    dataColumnCount=$((dataColumnCount + 1))
    headerColumnCount=${#headerArray[@]}

    if [ $headerColumnCount -eq $dataColumnCount ]; then
        return 0  # Sizes match
    else
        return 1  # Sizes do not match
    fi
}

# Function that fetches the data from various sources and returns an array
fetchDataRow() {
    # === Header: Analyser ===
    analyserName=$(hostname)
    dataString=("$analyserName")

    # === Header: Energy ===
    if [ -e "$energyFile" ]; then
        dataEnergy=$(cat "$energyFile")
    else
        dataEnergy=$defaultValue
    fi
    dataString+=("$dataEnergy")

    # === Header: Raw-Temperature and Calculated-Temperature ===
    # Check that the sensor file exists
    if [ -e "$sensorFile" ]; then
        # Read in the comma separated values from the sensor file
        IFS=',' read -r -a sensorData <<< $(cat "$sensorFile")

        # Header: Raw-Temperature
        dataRawTemp="${sensorData[2]}"  # Column 3 is Raw Temperature
        dataString+=("$dataRawTemp")

        # Header: Calculated-Temperature
        dataCalcTemp="${sensorData[3]}"  # Column 4 is Calculated Temperature
        dataString+=("$dataCalcTemp")
    else
        # Header: Raw-Temperature
        dataString+=($defaultValue)
        # Header: Calculated-Temperature
        dataString+=($defaultValue)
    fi

    # === Header: Bucket-Robot-Results ===
    if [ -e "$bucketRobotFile" ]; then
        dataBucketRobot=$(cat "$bucketRobotFile")
    else
        dataBucketRobot=$defaultValue
    fi
    dataString+=("$dataBucketRobot")

    # === Header: Status-Byte ===
    if [ -e "$statusByteFile" ]; then
        dataStatusByte=$(cat "$statusByteFile")
    else
        dataStatusByte=$defaultValue
    fi
    dataString+=("$dataStatusByte")

    # === Header: Flash-Delay ===
    # Extract the flash delay from the mq200ConfFile
    if [ -e "$mq200ConfFile" ]; then
        dataFlashDelay=$(grep -Po "(?<=\bFlashDelay=)\d+" "$mq200ConfFile")
    else
        dataFlashDelay=$defaultValue
    fi
    dataString+=("$dataFlashDelay")

    # === Header: Loadcell-Weight and Sample-Cabinet-Door ===
    if [ -e "$sampleCabinetFile" ] && [ -s "$sampleCabinetFile" ]; then
        # Read the values from the samplecabinet file
        IFS=',' read -r -a sampleCabinetData <<< $(cat "$sampleCabinetFile")

        # Header: Loadcell-Weight
        dataLoadcellWeight="${sampleCabinetData[0]}"  # First value
        # Header: Samplecabinet-Door
        dataCabinetDoor="${sampleCabinetData[1]}"  # Second value
    else
        # Use default values if the file doesn't exist or is empty
        dataLoadcellWeight=$defaultValue  # Default value for Loadcell-Weight
        dataCabinetDoor=$defaultValue    # Default value for Samplecabinet-Door
    fi
    dataString+=("$dataLoadcellWeight")
    dataString+=("$dataCabinetDoor")

    # === Header: Free-Memory ===
    dataFreeMemory=$(echo `free | grep 'Mem' | awk '{print $4}'`)
    dataString+=("$dataFreeMemory")

    # === Header: Free-Root ===
    dataFreeRoot=$(echo `df | grep '/dev/mmcblk0p2' | awk '{print $4}'`)
    dataString+=("$dataFreeRoot")

    # === Header: Free-Overlay ===
    dataFreeOverlay=$(echo `df | grep '/dev/mmcblk0p3' | awk '{print $4}'`)
    dataString+=("$dataFreeOverlay")

    # === Header: Uptime ===
    uptimeSeconds=$(cat /proc/uptime | cut -d ' ' -f1)
    dataUptime=$(echo "$uptimeSeconds / 60" | bc)
    dataString+=("$dataUptime")

    # === Header: mqsembed-Running ===
    dataMqsembedRunning=$(if [ `ps -aux | grep "/OLMA/mqsembed" | grep -v "grep" | grep -c "/OLMA/mqsembed"` -ne 1 ]; then echo '0'; else echo '1'; fi)
    dataString+=("$dataMqsembedRunning")

    # === Header: mq200embed-Running  ===
    dataMq200embedRunning=$(if [ `ps -aux | grep "/OLMA/mq200embed" | grep -v "grep" | grep -c "/OLMA/mq200embed"` -ne 1 ]; then echo '0'; else echo '1'; fi)
    dataString+=("$dataMq200embedRunning")

    # === Header: getspec-Running  ===
    dataGetspecRunning=$(if [ `ps -aux | grep "/OLMA/getspec" | grep -v "grep" | grep -c "/OLMA/getspec"` -ne 1 ]; then echo '0'; else echo '1'; fi)
    dataString+=("$dataGetspecRunning")

    # === Header:  ===
    #data=$()
    #dataString+=("$data")


    # --> ADD ADDITIONAL SENSORS HERE: <--



    # --> DON'T ADD SENSOR AFTER THIS LINE <--


    # DON'T EDIT THIS AS THE MINERALS AND BASIC SENSORS MUST ALWAYS GO LAST
    # === Header: Mineral Values & Basic Sensor Values ===
    # The headers come from trainingConfFile and the data comes from newestFile

    # Read the values from newest.csv and append to dataString
    if [ -e "$newestFile" ]; then
        # Read the line from newest.csv, remove the first two fields and remove non-printable characters
        dataValues=$(tail -n 1 "$newestFile" | cut -d ',' -f 3- | tr -cd '[:print:]')

        # Append the values to dataString
        dataString+=("$dataValues")
    else
        # Use default values if the file doesn't exist
        dataString+=("$defaultValue")
    fi

    # Comma separate all the values
    echo "${dataString[*]}" | tr ' ' ','

}

# =============== MAIN CODE ===============

# Remove the file just for testing
#rm "$databaseFile"

# Extract the mineral names
headerArray+=($(awk -F= '/\[Mineral Names\]/{flag=1; next} /\[/{flag=0} flag {print $2}' "$trainingConfFile"))

# Ensure that headerArray contains unique values
headerArray=($(echo "${headerArray[@]}" | tr ' ' '\n'))


# Check if the CSV file exists
if [ ! -e "$databaseFile" ]; then
    # If the file doesn't exist, create it and write the header
    headerColumnCount=${#headerArray[@]}
    for ((i=0; i<$headerColumnCount; i++)); do
        if [ $i -eq $((headerColumnCount-1)) ]; then
            echo -n "${headerArray[$i]}"
            echo -n "${headerArray[$i]}" >> "$databaseFile"
        else
            echo -n "${headerArray[$i]},"
            echo -n "${headerArray[$i]}," >> "$databaseFile"
        fi
    done
    echo ""
    echo "" >> "$databaseFile"
fi

# Before trying to write to the file, first clean the file of all non-printable characters
sed -i '/\x00/d' $databaseFile

# === Header: Date-and-Time ===
dateTime=$(date +"%Y-%m-%d %H:%M:%S")
# Append all the data to a comma-separated string
data=$(fetchDataRow)
# Put the date first and then the rest of the data as the data has a space between the date and the time and you want to keep the date-time as one item separated by a space
dataString="$dateTime,$data"

# Output the data for the user to see if they run it manually
echo $dataString

# Check if the amount of colums of data match the amount of columns in the header
checkColumnCount

if [ $? -eq 0 ]; then
    # Sizes match, fetch and write the data
    echo "$dataString" >> "$databaseFile"
else
    # Sizes do not match, output an error message
    errorMessage="Header array and Data array sizes do not match. Header columns: $headerColumnCount, Data columns: $dataColumnCount"
    echo "$errorMessage" >> "$databaseFile"
fi

