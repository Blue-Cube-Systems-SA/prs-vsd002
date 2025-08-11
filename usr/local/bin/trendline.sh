#!/bin/bash
VERSION="1.0.0"
echo 'Usage: trendline.sh [Olma root, e.g. "/OLMA/"] [Fieldnames|Descriptions] [2>/dev/null]' >&2
if [[ $# -gt 0 ]]
then OLMAROOT=$1
else OLMAROOT='/OLMA/'
fi
function Description {
    for FIELD in "$@"
    do
        TAB=$'\t'
        D="`grep "$FIELD" /OLMA/Field_Descriptions.csv |sed -e "s/^.*[,$TAB]\+//" -e 's/[[:space:]]*//'`"
        if [[ "$D" == "" ]]
        then
            if   [[ "$FIELD" = "Energy" ]]; then echo -n 'Energy,'
            elif [[ "$FIELD" = "Offs_0" ]]; then echo -n 'Offset0,'
            elif [[ "$FIELD" = "Offs_1" ]]; then echo -n 'Offset1,'
            elif [[ "$FIELD" = "Off_Emu" ]]; then echo -n 'OffsetC,'
            elif [[ "$FIELD" = "Temp_C" ]]; then echo -n 'Temperature [degC],'
            elif [[ "$FIELD" = "TempRaw" ]]; then echo -n 'Temperature [raw],'
            elif [[ "$FIELD" = "Pressur" ]]; then echo -n 'Pressure [kPa],'
            elif [[ "$FIELD" = "Humid" ]]; then echo -n 'Humidity [%RH],'
            elif [[ "$FIELD" = "Flag_V" ]]; then echo -n 'Vflag [V_10],'
            elif [[ "$FIELD" = "Board_V" ]]; then echo -n 'Vver [V_10],'
            elif [[ "$FIELD" = "PS0" ]]; then echo -n 'PS0,'
            elif [[ "$FIELD" = "PS1" ]]; then echo -n 'PS1,'
            elif [[ "$FIELD" = "PS2" ]]; then echo -n 'PS2,'
            elif [[ "$FIELD" = "PS3" ]]; then echo -n 'PS3,'
            elif [[ "$FIELD" = "PS4" ]]; then echo -n 'PS4,'
            elif [[ "$FIELD" = "PS5" ]]; then echo -n 'PS5,'
            elif [[ "$FIELD" = "PS6" ]]; then echo -n 'PS6,'
            elif [[ "$FIELD" = "PS7" ]]; then echo -n 'PS7,'
            elif [[ "$FIELD" = "PS8" ]]; then echo -n 'PS8,'
            elif [[ "$FIELD" = "PS9" ]]; then echo -n 'PS9,'
            elif [[ "$FIELD" = "PS10" ]]; then echo -n 'PS10,'
            elif [[ "$FIELD" = "PS11" ]]; then echo -n 'PS11,'
            elif [[ "$FIELD" = "PS12" ]]; then echo -n 'PS12,'
            elif [[ "$FIELD" = "PS13" ]]; then echo -n 'PS13,'
            elif [[ "$FIELD" = "PS14" ]]; then echo -n 'PS14,'
            elif [[ "$FIELD" = "PS15" ]]; then echo -n 'PS15,'
            elif [[ "$FIELD" = "PS16" ]]; then echo -n 'PS16,'
            elif [[ "$FIELD" = "Flow" ]]; then echo -n 'Flow,'
            elif [[ "$FIELD" = "Density" ]]; then echo -n 'Density,'
            elif [[ "$FIELD" = "Blank1" ]]; then echo -n 'Blank1,'
            elif [[ "$FIELD" = "Blank2" ]]; then echo -n 'Blank2,'
            elif [[ "$FIELD" = "Blank3" ]]; then echo -n 'Blank3,'
            elif [[ "$FIELD" = "Blank4" ]]; then echo -n 'Blank4,'
            elif [[ "$FIELD" = "B_R" ]]; then echo -n 'Bucket Robot results,'
            elif [[ "$FIELD" = "OI" ]]; then echo -n 'OI,'
            elif [[ "$FIELD" = "Unknown" ]]; then echo -n 'Unknown,'
            elif [[ "$FIELD" = "TOffset" ]]; then echo -n 'T-Offset,'
            elif [[ "$FIELD" = "Intens" ]]; then echo -n 'Intensity,'
            elif [[ "$FIELD" = "Light_I" ]]; then echo -n 'Light-Int,'
            elif [[ "$FIELD" = "Dark_I" ]]; then echo -n 'Dark-Int,'
            elif [[ "$FIELD" = "Stabil" ]]; then echo -n 'Stability,'
	    elif [[ "$FIELD" = "Status-Byte" ]]; then echo -n 'Status-Byte,'
            else echo "Error($FIELD),"
            fi
        else
            echo -n $D,
        fi
    done
}

MINERALCOUNT=`grep " *MineralCount *=" $OLMAROOT/conf/training.conf |head -n1 |sed -e 's/^ *MineralCount *=[^0-9]*//' -e 's/[^.0-9]//g'`
STREAM=`grep " *MachineName *="  $OLMAROOT/mq200.conf         |head -n1 |sed -e 's/^ *MachineName *= *//' -e 's/[[:space:]]//g'`
if [[ "$2" = "Fieldnames" || "$2" = "F" ]] ## Not more than 7 characters per DB field name
then
    echo -n `date +"%Y/%m/%d %H:%M:%S"`",$STREAM,"
   ## newest.csv ##
    MINERAL=0
    MIN=0
    for NAME in `tail -n+3 $OLMAROOT/conf/MapMat.csv |sed -e 's/ *,.*//' -e "s/[[:space:]]//g"`
    do
        let MINERAL=$MINERAL+1
        if [[ $MINERAL -le $MINERALCOUNT ]]
        then
            if   [[ $NAME = "OI"         ]]; then echo -n 'OI,'
            elif [[ $NAME = "Unknown"    ]]; then echo -n 'Unknown,'
            elif [[ $NAME = "T-Offset"   ]]; then echo -n 'TOffset,'
            elif [[ $NAME = "Intensity"  ]]; then echo -n 'Intens,'
            elif [[ $NAME = "Light-Int"  ]]; then echo -n 'Light_I,'
            elif [[ $NAME = "Dark-Int"   ]]; then echo -n 'Dark_I,'
            elif [[ $NAME = "Stability"  ]]; then echo -n 'Stabil,'
            else let MIN+=1; echo -n 'Min'$MIN','
            fi
        fi
    done
   ## sensor.csv ##
    echo -n 'Offs_0,Offs_1,Off_Emu,Temp_C,TempRaw,Pressur,Humid,Flag_V,Board_V,'
   ## energy_newest.csv ##
    echo -n 'Energy,'
   ## pumpstate_newest.csv ##
    echo -n 'PS0,PS1,PS2,PS3,PS4,PS5,PS6,PS7,PS8,PS9,PS10,PS11,PS12,PS13,PS14,PS15,'
   ## profibus_read.csv ##
    echo -n 'Flow,Density,Blank1,Blank2,Blank3,Blank4,'
   ## bucket_robot.out ##
    echo -n 'B_R,'
   ## MQi Status Bit ##
    echo -n 'Status-Byte'
   ## END ##
    echo -n '(Database Field Names)'
elif [[ "$2" = "Descriptions" || "$2" = "D" ]]
then
    echo -n `date +"%Y/%m/%d %H:%M:%S"`",$STREAM,"
   ## newest.csv ##
    for (( MINERAL=1; MINERAL<=$MINERALCOUNT; MINERAL+=1 ))
    do
        echo -n `sed -ne '/ *\[ *Mineral Names *\]/,/^ *\[/p' $OLMAROOT/conf/training.conf |grep "Mineral$MINERAL *=" |sed -e 's/^.*= *//' -e 's/ *$//'`','
    done
   ## sensor.csv ##
    echo -n `Description Offs_0 Offs_1 Off_Emu Temp_C TempRaw Pressur Humid Flag_V Board_V`
   ## energy_newest.csv ##
    echo -n `Description Energy`
   ## pumpstate_newest.csv ##
    echo -n `Description PS0 PS1 PS2 PS3 PS4 PS5 PS6 PS7 PS8 PS9 PS10 PS11 PS12 PS13 PS14 PS15`
   ## profibus_read.csv ##
    echo -n `Description Flow Density Blank1 Blank2 Blank3 Blank4`
   ## bucket_robot.out ##
    echo -n `Description B_R`
   ## MQi Status Bit ##
    echo -n `Description Status-Byte`
   ## END ##
    echo -n '(Friendly Column Names)'
else
    let COMMAS=$MINERALCOUNT+2+1
    echo `tail -n1 $OLMAROOT/data/newest.csv`,,,,,,,,,,,,,,,,,,,,,,,,, |cut -d, -f1-$COMMAS |tr -d '\n'  # 17 fields for MineralCount=15(+2), for ComponentCount=8(+7)
    echo `tail -n1 /OLMA/data/sensor.csv`,,,,,,,,,          |cut -d, -f1-10 |tr -d '\n'  # 9 sensors
    echo `tail -n1 /OLMA/data/energy_newest.csv`,,,,,,,,    |cut -d, -f1-2  |tr -d '\n'  # 1 energy requirement. {Use >=8 commas for cut bug}
    echo `tail -n1 /OLMA/data/pumpstate_newest.csv`,,,,,,,,,,,,,, |cut -d, -f1-17  |tr -d '\n'  # 16 pump states
    echo `tail -n1 /OLMA/data/profibus_read.csv`,,,,,,,,    |cut -d, -f1-7  |tr -d '\n'  # 6 readings, Flow and Density from anybus
    echo `tail -n1 $OLMAROOT/data/samplecabinet.csv`,,,,,,,,, |cut -d, -f1-3  |tr -d '\n'  # samplecabinet readings 2
    echo `grep ^FlashDelay $OLMAROOT/mq200.conf  | sed s/'FlashDelay='//g`,,,,, |cut -d, -f1-2  |tr -d '\n' #output flash delay
    echo `tail -n1 $OLMAROOT/data/bucket_robot.out`,,,,,,,, |cut -d, -f1-2  |tr -d '\n'  # 1 output from bucketrobot
    echo  `tail -n1 $OLMAROOT/data/mqi_status_byte` |tr -d '\n'  # MQi Status Byte
    echo  "," |tr -d '\n'  # MQi Status Byte comma
fi
echo

