#!/bin/bash

# This file calls trendline.sh and pipes it to the tosend file
# It also ensures that the tosend file does not become too long

VERSION="1.2-arm"

# Source configuration file
source /etc/bluecube/mqi.conf

tosend_file="/OLMA/data/$(hostname)_tosend"

# Function to write fieldnames and descriptions to the tosend file
write_fieldnames_and_descriptions() {
    if [ ! -f /tmp/tosendlinecalled.flag ]; then
        # Check if the unit is multiplex or not
        if [ -d "/OLMA/OLMA-A/" ]; then
            /usr/local/bin/trendline.sh '/OLMA/OLMA-A/' Fieldnames
            /usr/local/bin/trendline.sh '/OLMA/OLMA-B/' Fieldnames
            /usr/local/bin/trendline.sh '/OLMA/OLMA-A/' Descriptions
            /usr/local/bin/trendline.sh '/OLMA/OLMA-B/' Descriptions
            touch /tmp/tosendlinecalled.flag
        else
            /usr/local/bin/trendline.sh '/OLMA/' Fieldnames
            /usr/local/bin/trendline.sh '/OLMA/' Descriptions
            touch /tmp/tosendlinecalled.flag
        fi
    fi
}

# Function to write data to the tosend file
write_data_to_tosend_file() {
    # Check if the unit is multiplex or not
    if [ -d "/OLMA/OLMA-A/" ]; then
        /usr/local/bin/trendline.sh '/OLMA/OLMA-A/' "$1" >> "$tosend_file"
        /usr/local/bin/trendline.sh '/OLMA/OLMA-B/' "$1" >> "$tosend_file"
    else
        /usr/local/bin/trendline.sh '/OLMA/' "$1" >> "$tosend_file"
    fi
}

# Function to remove lines before the first line matching the date format and trim
trim_tosend() {
    if [ -f "$tosend_file" ]; then
        # Check if TOSEND_MAX_LINES is set, if not, default to 43200 lines
        TOSEND_MAX_LINES=${TOSEND_MAX_LINES:-43200}

        # Get the total number of lines in the tosend file
        local total_lines=$(wc -l < "$tosend_file")

        # Only trim if the number of lines exceeds TOSEND_MAX_LINES + 720 (12 hours worth of data)
        # This is to prevent the script from trimming every single time
        if [ "$total_lines" -gt "$((TOSEND_MAX_LINES + 720))" ]; then
            # Use awk to remove lines before the first date-matching line
            awk -v max_lines="$TOSEND_MAX_LINES" '
            /^[0-9]{4}\/[0-9]{2}\/[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2},/ {found=1}
            found { print }
            ' "$tosend_file" > "${tosend_file}_tmp"
            
            # Use tail to trim the file to the last max_lines
            tail -n "$TOSEND_MAX_LINES" "${tosend_file}_tmp" > "${tosend_file}_trimmed"

            # Replace the original tosend file with the trimmed file
            mv "${tosend_file}_trimmed" "$tosend_file"
            
            # Clean up temporary file
            rm "${tosend_file}_tmp"
        fi
    else
        echo "Tosend file not found. Skipping trimming."
    fi
}

# Call function to write fieldnames and descriptions
write_fieldnames_and_descriptions

# Call function to remove lines before the first matching date format and trim lines
trim_tosend

# Process the provided argument and append to tosend file
write_data_to_tosend_file "$1"
