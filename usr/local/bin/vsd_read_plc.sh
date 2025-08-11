#!/bin/bash
set -e

LOCKFILE="/OLMA/input/vsd_read_plc.lock"
exec 200>"$LOCKFILE"
flock -n 200 || exit 1

CSV_FILE="/OLMA/data/profibus_read.csv"

if IFS=',' read -r plant_status vis_status _ < "$CSV_FILE"; then

    # --- PLANT STATUS LOGIC ---
    if [ "$plant_status" -eq 0 ]; then
        [ -e /OLMA/input/plant_off.flag ] && rm /OLMA/input/plant_off.flag
    else
        touch /OLMA/input/plant_off.flag
    fi

    # --- VISCOSITY LOGIC ---
    if [ "$vis_status" -eq 0 ]; then
        [ -e /OLMA/input/hi_vis.flag ] && rm /OLMA/input/hi_vis.flag
    else
        touch /OLMA/input/hi_vis.flag
    fi

else
    echo "Error: Unable to read values from $CSV_FILE"
    exec 200>&-  # Ensure lock is released even on error
    exit 1
fi

exec 200>&-  # Release lock after successful run
