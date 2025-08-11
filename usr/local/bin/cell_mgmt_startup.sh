#!/bin/bash

VERSION="v1.0.0-arm"

SIM_PIN=9779
needs_pin=0

# timeouts (in seconds)
POWER_CYCLE_DELAY=30
APN_DELAY=30
PIN_DELAY=20
SIM_READY_DELAY=10
SIM_READY_MAX_TRIES=5
SIM_CONNECTED_RETRY_DELAY=30
SIM_CONNECTED_MAX_TRIES=5

log() {
  local msg="$1"
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] $msg" >> /OLMA/data/cell_setup.log
}

run_and_wait() {
  local cmd="$1"
  local delay="$2"
  echo "$cmd"
  eval "$cmd"
  sleep "$delay"
}

retry_check() {
  local check_cmd="$1"
  local delay="$2"
  local max_tries="$3"
  local attempt=1

  until eval "$check_cmd"; do
    if (( attempt >= max_tries )); then
      echo "ERROR: condition failed after $attempt attempts: $check_cmd"
      return 1
    fi
    echo "Waiting for condition ($attempt/$max_tries)..."
    sleep "$delay"
    (( attempt++ ))
  done

  echo "Condition met: $check_cmd"
  return 0
}

# Power-cycle the modem
run_and_wait "cell_mgmt power_off" "$POWER_CYCLE_DELAY"
run_and_wait "cell_mgmt power_on"  "$POWER_CYCLE_DELAY"

# Set APN
run_and_wait "cell_mgmt set_apn internet" "$APN_DELAY"

# Unlock PIN if needed
if (( needs_pin )); then
  run_and_wait "cell_mgmt unlock_pin $SIM_PIN" "$PIN_DELAY"
fi

# Wait for SIM to report READY
if ! retry_check "cell_mgmt sim_status | grep -q '+CPIN: READY'" \
                 "$SIM_READY_DELAY" "$SIM_READY_MAX_TRIES"; then
  echo "Failed to detect SIM readiness; exiting."
  exit 1
fi

# Start the modem and wait for connected status
attempt=1
until cell_mgmt start && cell_mgmt status | grep -q "Status: connected"; do
  if (( attempt >= SIM_CONNECTED_MAX_TRIES )); then
    echo "ERROR: cell failed to connect after $attempt attempts."
    exit 1
  fi
  echo "Waiting for SIM to connect ($attempt/$SIM_CONNECTED_MAX_TRIES)..."
  sleep "$SIM_CONNECTED_RETRY_DELAY"
  (( attempt++ ))
done

echo "Cell is powered on, unlocked, and connected."
