#!/bin/bash

set -e

LOCKFILE="/OLMA/input/vsd_sync_flags.lock"

# Use flock to ensure only one instance runs
exec 200>"$LOCKFILE"
flock -n 200 || exit 1

REMOTE=VSD
REMOTE_DIR="/OLMA/input"
LOCAL_DIR="/OLMA/input"

mkdir -p "$LOCAL_DIR"

### ---- Local to Remote ----
for file in hi_vis.flag plant_off.flag; do
    LOCAL_FILE="$LOCAL_DIR/$file"
    REMOTE_FILE="$REMOTE_DIR/$file"

    if [[ -f "$LOCAL_FILE" ]]; then
        echo "[$file] Found locally — uploading to remote."
        scp -q "$LOCAL_FILE" "$REMOTE:$REMOTE_FILE"
    else
        echo "[$file] Not found locally — deleting on remote."
        ssh "$REMOTE" "rm -f '$REMOTE_FILE'"
    fi
done

### ---- Remote to Local ----
for file in vsd_alarm.flag vsd_rinse.flag; do
    LOCAL_FILE="$LOCAL_DIR/$file"
    REMOTE_FILE="$REMOTE_DIR/$file"

    echo "[$file] Checking remote..."

    if ssh "$REMOTE" "[ -f '$REMOTE_FILE' ]"; then
        echo "[$file] Found remotely — downloading to local."
        scp -q "$REMOTE:$REMOTE_FILE" "$LOCAL_FILE"
    else
        echo "[$file] Not found remotely — deleting locally."
        rm -f "$LOCAL_FILE"
    fi
done

# ---- Release lock ----
exec 200>&-
