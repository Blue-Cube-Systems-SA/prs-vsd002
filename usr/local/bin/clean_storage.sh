#!/bin/bash

# The purpose of this script is to remove all files older than a certain time for housekeeping purposes

VERSION=1.0-arm

source /etc/bluecube/mqi.conf
source /etc/bluecube/terminal_colours.conf

# List of directories to clean
DIRECTORIES=("/OLMA/data" "/var/OLMA/dak")

echo -e "${COLOR_GREEN}Removing files older than $MONTHS_TO_KEEP months from the following directories:${COLOR_RESET}"

# List directories
for dir in "${DIRECTORIES[@]}"; do
    echo "$dir"
done

# Add a new line
echo

# Display message
echo -e "${COLOR_GREEN}Deleting the following files:${COLOR_RESET}"

# Iterate through directories, list files older than specified months, and delete them
files_deleted=0
for dir in "${DIRECTORIES[@]}"; do
    # Check if files exist before attempting deletion
    files_to_delete=$(find "$dir" -type f ! -newermt "$(date -d "$MONTHS_TO_KEEP months ago" '+%Y-%m-%d %H:%M:%S')" -exec stat {} + 2>/dev/null | wc -l)
    if [ "$files_to_delete" -gt 0 ]; then
        find "$dir" -type f ! -newermt "$(date -d "$MONTHS_TO_KEEP months ago" '+%Y-%m-%d %H:%M:%S')" -exec sh -c "echo '${COLOR_RED}{}${COLOR_RESET}'; rm '{}';" \;
        files_deleted=1
    fi
done

# Check if no files were deleted
if [ "$files_deleted" -eq 0 ]; then
    echo -e "${COLOR_RED}No files older than $MONTHS_TO_KEEP months, not deleting anything.${COLOR_RESET}"
fi
