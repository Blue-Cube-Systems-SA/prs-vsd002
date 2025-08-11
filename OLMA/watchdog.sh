#!/bin/bash
# -----------------------------------------------------------------------------
# Overview:
#   Monitors system health (sensor data, file updates, serial port status, etc.).
#   Logs critical events (only when a reboot is about to occur) with levels.
#   Prints a detailed terminal summary showing each diagnostic test’s status.
#   Triggers software or system reboots if conditions demand.
# -----------------------------------------------------------------------------

VERSION="2.1.2-arm"

# Source terminal colours
source /etc/bluecube/terminal_colours.conf

# Helper functions for colourized output
print_error()   { echo -e "${COLOR_RED}ERROR: $1${COLOR_RESET}"; }
print_warning() { echo -e "${COLOR_YELLOW}WARNING: $1${COLOR_RESET}"; }
print_info()    { echo -e "${COLOR_CYAN}INFO: $1${COLOR_RESET}"; }
print_success() { echo -e "${COLOR_GREEN}SUCCESS: $1${COLOR_RESET}"; }

# Define bit constants (values must match original assignments)
readonly BIT_NORMAL=2
readonly BIT_WARNING=4
readonly BIT_FAULT=8
readonly BIT_TOFFSET=16      # For T-offset out-of-spec (if enabled)
readonly BIT_OI_HIGH=32
readonly BIT_LUXCOMP_NOT_UPDATED=64
readonly BIT_INSTABILITY=128
readonly BIT_AUTOSAMPLE=256
readonly BIT_OI_VERY_HIGH=1024
readonly BIT_INTERNAL_COMMS=2048
readonly BIT_VSD_ALARM=4096

# File locations and unified var file for dynamic state variables
hostname=$(cat /etc/hostname)
watchdog_var_file="/OLMA/data/watchdog.var"  # Contains various state variables
watchdog_file="/OLMA/input/watchdog.flag"
watchdog_log_file="/OLMA/data/watchdog.log"
tosend_file="/OLMA/data/${hostname}_tosend"
newest_csv_file="/OLMA/data/newest.csv"
toffset_file="/OLMA/heater.conf"
auto_sample_bit_file="/OLMA/input/autoSampleBit.flag"
auto_sample_bit_file1="/OLMA/input/autoSampleBit1.flag"

# Limits (in minutes or appropriate units)
readonly TOFFSET_OUTOFSPEC_SCAN=10
readonly TOFFSET_NOCHANGE_MAX=10
readonly NEWESTCSV_NOCHANGE_MAX=10
readonly NEWEST_MISSING_PERIOD_MAX=5
readonly LIGHTINT_NOCHANGE_MAX_HR=24
readonly DARKINT_NOCHANGE_MAX_HR=$((24 * 7))
readonly REBOOT_WAIT_DEFAULT=15
readonly WATCHDOG_MAX_AGE=10             # Minutes
readonly MAX_INSTABILITY=5
readonly HIGH_OI_THRESHOLD=1
readonly MAX_OI_THRESHOLD=4.5
readonly SOFT_REBOOT_WAIT=10         # minutes
readonly HARD_REBOOT_WAIT=30        # minutes
readonly COUNTER_EXPIRY_WINDOW=1440 #minutes
readonly MAX_SOFT_REBOOT_ATTEMPTS=2     # Number of software reboots before doing a hard reboot

# Global flags and counters (in-memory; dynamic state is stored in watchdog.var)
warning_flag=0
error_flag=0
reboot_flag=0
software_reboot_flag=0

# Variables for training.conf mineral columns
oi_col=0
t_offset_col=0
light_int_col=0
dark_int_col=0
stabil_col=0

# Declare associative arrays to hold each test's status and reboot-causing test results.
declare -A test_results
declare -A reboot_reasons

##############################################
# Unified Logging Function with log levels
##############################################
log() {
    local msg="$1"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $msg" >> "$watchdog_log_file"
}

##############################################
# Function to get failure reasons from tests that caused a reboot.
##############################################
get_failure_reasons() {
    local reasons=""
    for test in "${!reboot_reasons[@]}"; do
        reboot_message=${reboot_reasons[$test]}
        reasons+="${reboot_message} & "
    done
    reasons="${reasons% & }"  # Remove trailing & and space
    echo "$reasons"
}

##############################################
# Final Summary Function - lists each test individually
##############################################
print_summary() {
    echo ""
    echo "======================================"
    echo "Watchdog Summary at $(date)"
    echo "Status Byte Value : $status_bit_val"
    echo "--------------------------------------"
    echo "Test Results:"
    # Print header with column names
    printf "  %-25s | %s\n" "Test Name" "Status"
    printf "  %-25s-+-%s\n" "-------------------------" "--------"
    for test in "Crontab Permissions" "Serial Port 0 (getspec)" "Serial Port 1 (mqsembed)" "T-offset Update" "Light Intensity Update" "Dark Intensity Update" "T-offset In Range" "OI In Range" "Stability In Range" "Watchdog Flag" "VSD Alarm Flag" "newest.csv Update"; do
        printf "  %-25s | %s\n" "$test" "${test_results[$test]}"
    done
    echo "======================================"
    echo ""
}

##############################################
# Load dynamic state variables from the unified var file.
##############################################
load_watchdog_vars() {
    if [ -f "$watchdog_var_file" ]; then
        source "$watchdog_var_file"
    else
        last_hard_reboot_date=0
        last_soft_reboot_date=0
        soft_reboot_attempts=0
        status_bit_val=0
        newest_missing_period=0
        watchdog_timer_bit=0
        first_soft_reboot_date=0
    fi
}

##############################################
# Save dynamic state variables to the unified var file.
##############################################
save_watchdog_vars() {
    cat <<EOF > "$watchdog_var_file"
last_hard_reboot_date=$last_hard_reboot_date
last_soft_reboot_date=$last_soft_reboot_date
soft_reboot_attempts=$soft_reboot_attempts
status_bit_val=$status_bit_val
newest_missing_period=$newest_missing_period
watchdog_timer_bit=$watchdog_timer_bit
first_soft_reboot_date=$first_soft_reboot_date
EOF
}

# Helper function to format a duration given in minutes.
format_duration() {
    local total_minutes="$1"
    local days=$(( total_minutes / 1440 ))
    local remainder_minutes=$(( total_minutes % 1440 ))
    local hours=$(( remainder_minutes / 60 ))
    local minutes=$(( remainder_minutes % 60 ))
    local duration=""
    
    if [ "$days" -gt 0 ]; then
        duration="${days}d ${hours}h ${minutes}m"
    elif [ "$hours" -gt 0 ]; then
        duration="${hours}h ${minutes}m"
    else
        duration="${minutes}m"
    fi
    echo "$duration"
}

##############################################
# Parse training.conf to extract mineral column assignments.
##############################################
parse_training_conf() {
    local training_conf_file="/OLMA/conf/training.conf"
    if [ ! -f "$training_conf_file" ]; then
        print_error "training.conf file not found."
        exit 1
    fi

    local in_mineral_section=0
    while IFS='=' read -r key value; do
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        # Start of the Mineral Names section
        if [[ "$key" == "[Mineral Names]" ]]; then
            in_mineral_section=1
            continue
        fi
        # Exit mineral section if a new section header is encountered
        if [ $in_mineral_section -eq 1 ] && [[ "$key" =~ ^\[.*\]$ ]]; then
            break
        fi
        if [ $in_mineral_section -eq 1 ]; then
            if [[ "$key" =~ ^Mineral([0-9]+)$ ]]; then
                local mineral_num="${BASH_REMATCH[1]}"
                case "$value" in
                    "OI")
                        oi_col=$(( mineral_num + 2 ))
                        ;;
                    "T-Offset")
                        t_offset_col=$(( mineral_num + 2 ))
                        ;;
                    "Light-Intensity")
                        light_int_col=$(( mineral_num + 2 ))
                        dark_int_col=$(( light_int_col + 1 ))
                        ;;
                    "Stability")
                        stabil_col=$(( mineral_num + 2 ))
                        ;;
                esac
                if [ "$oi_col" -ne 0 ] && [ "$t_offset_col" -ne 0 ] && [ "$light_int_col" -ne 0 ] && [ "$stabil_col" -ne 0 ]; then
                    break
                fi
            fi
        fi
    done < "$training_conf_file"
}

##############################################
# Flip watchdog timer bit and handle autoSample flags.
##############################################
update_watchdog_timer() {
    if [ -z "$watchdog_timer_bit" ]; then
        watchdog_timer_bit=0
    fi
    # Toggle timer bit
    if [ "$watchdog_timer_bit" -eq 0 ]; then
        watchdog_timer_bit=1
    else
        watchdog_timer_bit=0
    fi
    status_bit_val=$(( status_bit_val + watchdog_timer_bit ))
    
    if [ -f "$auto_sample_bit_file1" ]; then
        rm -f "$auto_sample_bit_file1"
        status_bit_val=$(( status_bit_val + BIT_AUTOSAMPLE ))
    elif [ -f "$auto_sample_bit_file" ]; then
        rm -f "$auto_sample_bit_file"
        touch "$auto_sample_bit_file1"
        status_bit_val=$(( status_bit_val + BIT_AUTOSAMPLE ))
    fi
    save_watchdog_vars
}

##############################################
# Validate OI value from the tosend file.
##############################################
check_oi() {
    if [ ! -f "$tosend_file" ]; then
        print_error "tosend file not found: $(basename "$tosend_file")"
        test_results["OI"]="Error: tosend file not found"
        return
    fi
    local oi
    oi=$(tail -n 1 "$tosend_file" | awk -v col="$oi_col" -F, '{ print $col }')
    if [[ $(echo "$oi > $HIGH_OI_THRESHOLD" | bc -l) -eq 1 && $(echo "$oi < $MAX_OI_THRESHOLD" | bc -l) -eq 1 ]]; then
        status_bit_val=$(( status_bit_val + BIT_OI_HIGH ))
        warning_flag=1
        print_warning "OI High (${HIGH_OI_THRESHOLD} < $oi < ${MAX_OI_THRESHOLD})"
        test_results["OI In Range"]="Warning"
    elif [[ $(echo "$oi > $MAX_OI_THRESHOLD" | bc -l) -eq 1 ]]; then
        status_bit_val=$(( status_bit_val + BIT_OI_VERY_HIGH ))
        error_flag=1
        print_error "OI Very High ($oi > ${MAX_OI_THRESHOLD})"
        test_results["OI In Range"]="Error"
    else
        test_results["OI In Range"]="OK"
    fi
}

##############################################
# Check if sensors update
##############################################
check_sensor_update() {
    # Parameters:
    #   $1 - Sensor Label (e.g., "Light Intensity", "Dark Intensity", "T-offset")
    #   $2 - File path to scan (e.g., "$tosend_file")
    #   $3 - CSV column number where the sensor value is located
    #   $4 - Threshold in minutes (if the sensor value remains unchanged for this many rows, warn)
    #   $5 - Update status bit flag (1 to update status_bit_val, 0 to skip)
    #   $6 - Status bit value to add if update flag is 1 (optional; default 0)
    local sensor_label="$1"
    local file="$2"
    local col="$3"
    local threshold_minutes="$4"
    local update_status_bit="$5"
    local status_bit_value="${6:-0}"

    local sensor_latest sensor_prev last_change_min formatted_duration result="OK"
    local last_update_row last_update_dt file_name line_count

    file_name=$(basename "$file")
    line_count=$(wc -l < "$file")
    if [ "$line_count" -lt "$threshold_minutes" ]; then
        print_warning "Not enough lines in $file_name (only $line_count lines). Skipping $sensor_label check."
        test_results["$sensor_label Update"]="Not checked"
        return
    fi

    # Capture the entire last row and extract the sensor value from its designated column.
    local latest_row
    latest_row=$(tail -n 1 "$file")
    sensor_latest=$(echo "$latest_row" | awk -v col="$col" -F, '{ print $col }')

    # Count how many consecutive rows (minutes) from the bottom have the same sensor value.
    last_change_min=$(tac "$file" | awk -v col="$col" -v latest="$sensor_latest" -F, '
        BEGIN { count=0 }
        { if ($col == latest) { count++ } else { exit } }
        END { print count }
    ' | head -n 1)

    # Search backwards (skipping the very first row) for the first row with a different sensor value.
    sensor_prev=$(tac "$file" | awk -v col="$col" -v latest="$sensor_latest" -F, 'NR==1 { next } { if ($col != latest) { print $col; exit } }')
    # Retrieve the entire row where the sensor last changed.
    last_update_row=$(tac "$file" | awk -v col="$col" -v latest="$sensor_latest" -F, 'NR==1 { next } { if ($col != latest) { print $0; exit } }')
    # Extract the date/time from the first field.
    last_update_dt=$(echo "$last_update_row" | awk -F, '{ print $1 }')

    # If no different value is found, assume it has "Never updated"
    if [ -z "$sensor_prev" ]; then
        sensor_prev="Never updated"
        last_change_min=$(wc -l < "$file")
    fi

    # Format the duration (using your helper function format_duration)
    formatted_duration=$(format_duration "$last_change_min")

    # If unchanged duration exceeds threshold, warn (and optionally update status bit)
    if [ "$last_change_min" -ge "$threshold_minutes" ]; then
        if [ "$update_status_bit" -eq 1 ] && [ "$status_bit_value" -ne 0 ]; then
            status_bit_val=$(( status_bit_val + status_bit_value ))
        fi
        warning_flag=1
        if [ "$sensor_prev" = "Never updated" ]; then
            print_warning "$sensor_label not updating (no update in >${formatted_duration})"
        else
            print_warning "$sensor_label not updating (last update ${last_update_dt} (~${formatted_duration} ago))"
        fi
        result="Warning"
    fi

    test_results["$sensor_label Update"]="$result"
}

##############################################
# Heater T-offset out-of-spec.
##############################################
check_t_offset_spec() {
    local toffset_old toffset_latest toffset_previous toffset_diff latest_toffset_diff
    local toffset_setting toffset_lower_lim toffset_upper_lim
    local result="OK"

    toffset_old=$(tail -n "$TOFFSET_OUTOFSPEC_SCAN" "$tosend_file" | head -n 1 | awk -v col="$t_offset_col" -F, '{ print $col }')
    toffset_latest=$(tail -n 1 "$tosend_file" | awk -v col="$t_offset_col" -F, '{ print $col }')
    toffset_previous=$(tail -n 2 "$tosend_file" | head -n 1 | awk -v col="$t_offset_col" -F, '{ print $col }')
    
    toffset_diff=$(awk -v n1="$toffset_latest" -v n2="$toffset_old" 'BEGIN {print n1 - n2}')
    latest_toffset_diff=$(awk -v n1="$toffset_latest" -v n2="$toffset_previous" 'BEGIN {print n1 - n2}')   

    toffset_setting=$(awk -F'=' '$1 == "offset" {print $2}' "$toffset_file")
    toffset_lower_lim=$(awk -v n1="$toffset_setting" 'BEGIN {print n1 - 15}')
    toffset_upper_lim=$(awk -v n1="$toffset_setting" 'BEGIN {print n1 + 15}')
    
    if [[ $(echo "$toffset_diff < 0" | bc -l) -eq 1 && \
          $(echo "$latest_toffset_diff < 0" | bc -l) -eq 1 && \
          $(echo "$toffset_latest < $toffset_lower_lim" | bc -l) -eq 1 ]]; then
        print_warning "T-offset out of range ($toffset_latest < $toffset_lower_lim)."
        result="Warning"
    elif [[ $(echo "$toffset_diff > 0" | bc -l) -eq 1 && \
            $(echo "$latest_toffset_diff > 0" | bc -l) -eq 1 && \
            $(echo "$toffset_latest > $toffset_upper_lim" | bc -l) -eq 1 ]]; then
        print_warning "T-offset out of range ($toffset_latest > $toffset_upper_lim)."
        result="Warning"
    fi
    test_results["T-offset In Range"]="$result"
}

##############################################
# Validate watchdog.flag file age.
##############################################
check_watchdog_flag() {
    local mtime curr_date date_diff_minutes duration
    local result="OK"
    if [ -f "$watchdog_file" ]; then
        mtime=$(stat -c "%Y" "$watchdog_file")
        curr_date=$(date +%s)
        date_diff_minutes=$(( (curr_date - mtime) / 60 ))
        if [ "$date_diff_minutes" -ge "$WATCHDOG_MAX_AGE" ]; then
            duration=$(format_duration "$date_diff_minutes")
            print_error "mq200 not consuming watchdog.flag (age: $duration)"
            rm -f "$watchdog_file"
            software_reboot_flag=1
            result="Error"
            reboot_reasons["Watchdog Flag"]="watchdog.flag not consumed for $WATCHDOG_MAX_AGE minutes"
            status_bit_val=$(( status_bit_val + BIT_INTERNAL_COMMS ))
            error_flag=1
        fi
    else
        touch "$watchdog_file"
    fi
    test_results["Watchdog Flag"]="$result"
}

##############################################
# Validate newest.csv update and existence.
##############################################
check_newest_csv() {
    local csv_date mtime curr_date date_diff_minutes duration
    local result="OK"
    if [ -f "$newest_csv_file" ]; then
        newest_missing_period=0
        csv_date=$(awk -F, '{ print $1; exit }' "$newest_csv_file")
        mtime=$(date -d "$csv_date" +%s 2>/dev/null)
        curr_date=$(date +%s)
        date_diff_minutes=$(( (curr_date - mtime) / 60 ))
        if [ "$date_diff_minutes" -ge "$NEWESTCSV_NOCHANGE_MAX" ]; then
            duration=$(format_duration "$date_diff_minutes")
            print_error "newest.csv update overdue: no changes in the last ${NEWESTCSV_NOCHANGE_MAX} minutes (last update: $duration ago)"
            software_reboot_flag=1
            result="Error"
            reboot_reasons["newest.csv Update"]="newest.csv not updating for $NEWESTCSV_NOCHANGE_MAX minutes"
            status_bit_val=$(( status_bit_val + BIT_INTERNAL_COMMS ))
            error_flag=1
        fi
    else
        newest_missing_period=$(( newest_missing_period + 1 ))
        if [ "$newest_missing_period" -ge "$NEWEST_MISSING_PERIOD_MAX" ]; then
            print_error "newest.csv missing for more than ${NEWEST_MISSING_PERIOD_MAX} minutes"
            newest_missing_period=0
            software_reboot_flag=1
            result="Error"
            reboot_reasons["newest.csv Update"]="newest.csv missing for $NEWEST_MISSING_PERIOD_MAX minutes"
            status_bit_val=$(( status_bit_val + BIT_INTERNAL_COMMS ))
            error_flag=1
        fi
    fi
    save_watchdog_vars
    test_results["newest.csv Update"]="$result"
}

##############################################
# Check UART Serial Ports (0 and 1)
# - Port 0: getspec (expected RS422/RS485-4W)
# - Port 1: mqsembed (expected RS485-2W)
# If misconfigured:
#   - Restart the relevant service
#   - Log to watchdog
#   - Flag error to Modbus/PLC
##############################################
check_serial_ports() {
    local port0_status port1_status
    local result0="OK"
    local result1="OK"

    # === Check Port 0 ===
    port0_status=$(mx-uart-ctl -p 0 2>/dev/null | awk -F"is " '{print $2}' | sed 's/ interface.*//')
    if [ "$port0_status" != "RS422/RS485-4W" ]; then
        print_error "Port 0 (getspec) expected UART mode 'RS422/RS485-4W', but got '$port0_status'. Restarting getspec.service..."
        log "Port 0 (getspec) expected UART mode 'RS422/RS485-4W', but got '$port0_status'. Restarting getspec.service."
        result0="Error"
        systemctl restart getspec.service

        # Flag internal comms issue
        status_bit_val=$((status_bit_val + BIT_INTERNAL_COMMS))
        error_flag=1
    fi

    # === Check Port 1 ===
    port1_status=$(mx-uart-ctl -p 1 2>/dev/null | awk -F"is " '{print $2}' | sed 's/ interface.*//')
    if [ "$port1_status" != "RS485-2W" ]; then
        print_error "Port 1 (mqsembed) expected UART mode 'RS485-2W', but got '$port1_status'. Restarting mqsembed.service..."
        log "Port 1 (mqsembed) expected UART mode 'RS485-2W', but got '$port1_status'. Restarting mqsembed.service."
        result1="Error"
        systemctl restart mqsembed.service
        
        # Flag internal comms issue
        status_bit_val=$((status_bit_val + BIT_INTERNAL_COMMS))
        error_flag=1
    fi

    # Update summary test result
    test_results["Serial Port 0 (getspec)"]="$result0"
    test_results["Serial Port 1 (mqsembed)"]="$result1"
}

##############################################
# Change crontab permissions if incorrect
##############################################

    check_crontab_permissions() {
    local crontab_file="/etc/crontab"
    local result="OK"

    # get current owner, group and mode
    local owner group mode
    owner=$(stat -c '%U' "$crontab_file")
    group=$(stat -c '%G' "$crontab_file")
    mode=$(stat -c '%A' "$crontab_file")

    # if anything isn’t root:root 644, fix it
    if [[ "$owner" != "root" || "$group" != "root" || "$mode" != "-rw-r--r--" ]]; then
        print_error "Crontab file ownership and/or permissions incorrect. Resetting to root:root 644 and restarting cron..."
        log         "Crontab file ownership and/or permissions incorrect. Resetting to root:root 644 and restarting cron... "

        chown root "$crontab_file"
        chgrp root "$crontab_file"
        chmod 644 "$crontab_file"
        systemctl restart cron

        result="Error"
    fi

    test_results["Crontab Permissions"]="$result"
}



##############################################
# Validate stability from tosend file.
##############################################
check_stability() {
    local stability
    local result="OK"
    stability=$(tail -n 1 "$tosend_file" | awk -v col="$stabil_col" -F, '{ print $col }')
    if [[ $(echo "$stability > $MAX_INSTABILITY" | bc -l) -eq 1 ]]; then
        status_bit_val=$(( status_bit_val + BIT_INSTABILITY ))
        warning_flag=1
        print_warning "Instability High ($stability > $MAX_INSTABILITY)"
        result="Warning"
    fi
    test_results["Stability In Range"]="$result"
}

##############################################
# Update status bit value based on warning and error flags.
##############################################
update_status_bits() {
    if [ "$warning_flag" -eq 1 ]; then
        status_bit_val=$(( status_bit_val + BIT_WARNING ))
    fi
    if [ "$error_flag" -eq 1 ]; then
        status_bit_val=$(( status_bit_val + BIT_FAULT ))
    fi
    if [ "$warning_flag" -eq 0 ] && [ "$error_flag" -eq 0 ]; then
        status_bit_val=$(( status_bit_val + BIT_NORMAL ))
        print_success "Normal Operation"
    fi
}

##############################################
# Handle software reboot if flagged.
# Only log when a reboot is actually about to occur, including the reasons (Failed test(s)).
##############################################
handle_software_reboot() {
    local curr_date date_diff next_soft_reboot_chance reasons
    local first_attempt_diff

    curr_date=$(date +%s)

     # Reset attempts if 24h have passed since first attempt without triggering reboot
        if [ "$first_soft_reboot_date" -ne 0 ]; then
            first_attempt_diff=$(( (curr_date - first_soft_reboot_date) / 60 ))
            if [ "$first_attempt_diff" -ge COUNTER_EXPIRY_WINDOW ]; then
                print_info "Resetting software reboot counter due to 24h expiry."
                soft_reboot_attempts=0
                first_soft_reboot_date=0
            fi
        fi

    if [ "$software_reboot_flag" -eq 1 ]; then
        date_diff=$(( (curr_date - last_soft_reboot_date) / 60 ))

        reasons=$(get_failure_reasons)
        if [ "$date_diff" -gt "$SOFT_REBOOT_WAIT" ]; then
            if [ "$soft_reboot_attempts" -ge "$MAX_SOFT_REBOOT_ATTEMPTS" ]; then
                reboot_flag=1
                soft_reboot_attempts=0
                first_soft_reboot_date=0
                log "Software Reboot: Max attempts reached. Failed test(s): $reasons"
                print_error "Software reboot attempts exceeded; full system reboot flagged."
            else
                soft_reboot_attempts=$(( soft_reboot_attempts + 1 ))
                if [ "$soft_reboot_attempts" -eq 1 ]; then
                    first_soft_reboot_date=$curr_date
                fi
                log "Software Reboot Attempt ${soft_reboot_attempts}/$MAX_SOFT_REBOOT_ATTEMPTS. Failed test(s): $reasons"
                print_warning "Software reboot attempt ${soft_reboot_attempts}/$MAX_SOFT_REBOOT_ATTEMPTS."
            fi

            last_soft_reboot_date=$curr_date
            systemctl stop heater.service
            systemctl stop mq200embed.service
            systemctl stop mqsembed.service
            systemctl stop getspec.service
            killall heater 2>/dev/null
            killall mq200embed 2>/dev/null
            killall sampleDetector 2>/dev/null
            killall mqsembed 2>/dev/null
            killall getspec 2>/dev/null
            systemctl start heater.service
            systemctl start modbus.service
            systemctl start getspec.service
            systemctl start mq200embed.service
            touch /OLMA/input/sample.sem
            systemctl start mqsembed.service
        else
            next_soft_reboot_chance=$((SOFT_REBOOT_WAIT - date_diff))
            if [ "$next_soft_reboot_chance" -le 0 ]; then
                next_soft_reboot_chance=1
            fi
            print_warning "Software Reboot Delayed. Waiting $next_soft_reboot_chance more minute(s)."
        fi
    fi
}


##############################################
# Handle full system reboot if flagged and wait period elapsed.
# Only log when a reboot is actually about to occur, including the reasons (Failed test(s)).
##############################################
handle_reboot() {
    local curr_date date_diff next_hard_reboot_chance reasons
    if [ "$reboot_flag" -eq 1 ]; then
        curr_date=$(date +%s)
        date_diff=$(( (curr_date - last_hard_reboot_date) / 60 ))
        reasons=$(get_failure_reasons)
        
        if [ "$date_diff" -ge "$HARD_REBOOT_WAIT" ]; then
            log "Hardware Reboot: $reasons"
            print_error "Initiating full system reboot now..."
            last_hard_reboot_date=$(date +%s)
            save_watchdog_vars
            reboot
        else
            next_hard_reboot_chance=$((HARD_REBOOT_WAIT - date_diff))
            if [ "$next_hard_reboot_chance" -le 0 ]; then
                next_hard_reboot_chance=1
            fi
            print_warning "Hard Reboot Delayed. Waiting $next_hard_reboot_chance more minute(s)."
            log "Hard Reboot Delayed. Waiting $next_hard_reboot_chance more minute(s)."
        fi
    fi
}

##############################################
# Check if VSD alarm flag file exists
##############################################
check_vsd_alarm_flag() {
    local result="OK"
    local vsd_flag_file="/OLMA/input/vsd_alarm.flag"

    if [ -f "$vsd_flag_file" ]; then
        print_error "VSD Alarm flag detected"
        result="Error"
        status_bit_val=$(( status_bit_val + BIT_VSD_ALARM ))
        error_flag=1
        reboot_reasons["VSD Alarm"]="vsd_alarm.flag present"
    fi

    test_results["VSD Alarm Flag"]="$result"
}

#############################################
# Main function to orchestrate the checks.
##############################################
main() {
    parse_training_conf
    load_watchdog_vars
    update_watchdog_timer

    check_crontab_permissions
    check_serial_ports
    check_sensor_update "T-offset" "$tosend_file" "$t_offset_col" "$TOFFSET_NOCHANGE_MAX" 0 0
    check_sensor_update "Light Intensity" "$tosend_file" "$light_int_col" $(( LIGHTINT_NOCHANGE_MAX_HR * 60 )) 1 $BIT_LUXCOMP_NOT_UPDATED
    check_sensor_update "Dark Intensity" "$tosend_file" "$dark_int_col" $(( DARKINT_NOCHANGE_MAX_HR * 60 )) 0 0
    check_t_offset_spec
    check_oi
    check_stability
    check_watchdog_flag
    check_newest_csv
    check_vsd_alarm_flag
   

    update_status_bits
    print_summary

    handle_software_reboot
    handle_reboot

    save_watchdog_vars
}

# Execute main function
main
