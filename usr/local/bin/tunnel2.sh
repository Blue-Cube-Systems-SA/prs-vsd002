#!/bin/bash

# The purpose of this script is to open a tunnel between the communications gateway and the Readings server

VERSION=1.3.1-arm

# Load configuration files
source /etc/bluecube/mqi.conf
source /etc/bluecube/cgw.conf
source /etc/bluecube/servers.conf

serialnumber="${CLI}${CGW}"
logFile="/OLMA/data/tunnel2.log"

# SSH options
SSH_OPTS="-o ServerAliveInterval=30 \
          -o ServerAliveCountMax=3 \
          -o ExitOnForwardFailure=yes \
          -c aes128-cbc"

# Log a message with a timestamp
log() {
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $1" >> "$logFile"
}

# Retrieve the remote port by connecting to the readings server over SSH.
retrieve_remote_port() {
    while true; do
        remoteport=$(ssh $SSH_OPTS "${olmaUser}@${readingsIP}" "~/private/tunnel-getport ${serialnumber}" 2>/dev/null)
        if [[ -n "$remoteport" ]]; then
            echo "Got remote port: $remoteport"
            return 0
        fi
        echo "Failed to get remote port, retrying"
        log "Failed to get remote port, retrying."
        sleep 100
    done
}

# Check if the SSH tunnel is alive by testing the remote port connection.
is_ssh_tunnel_alive() {
    ssh $SSH_OPTS "${olmaUser}@${readingsIP}" \
        "timeout 3 bash -c '</dev/tcp/127.0.0.1/${remoteport}' && echo OK" 2>/dev/null | grep -q "OK"
}

# Restart the SSH tunnel by cleaning up stale autossh/ssh processes and launching a new tunnel.
restart_ssh_tunnel() {
    echo "Restarting SSH tunnel"
    log "Restarting SSH tunnel"

    # Check for any stale autossh processes that are using the same reverse tunnel.
    stale_pids=$(ps aux | grep "autossh.*-R ${remoteport}:127.0.0.1:22" | grep -v grep | awk '{print $2}')
    if [[ -n "$stale_pids" ]]; then
        echo "Found stale autossh processes: $stale_pids, killing them..."
        log "Found stale autossh processes: $stale_pids, killing them..."
        kill $stale_pids
        sleep 5  # Allow time for the port to be released.
    fi

    # Also kill any direct SSH processes matching the same remote forwarding.
    pkill -f "ssh.*${olmaUser}@${readingsIP}"
    
    # Launch a new autossh tunnel.
    autossh -f $SSH_OPTS -M 0 -N -R "${remoteport}:127.0.0.1:22" "${olmaUser}@${readingsIP}"
    
    sleep 5
    
    if is_ssh_tunnel_alive; then
        echo "SSH tunnel is up."
        return 0
    else
        echo "SSH tunnel restart failed."
        log "SSH tunnel restart failed."
        return 1
    fi
}

# Check if the remote port is listening on the readings server.
is_remote_port_listening() {
    status=$(ssh $SSH_OPTS "${olmaUser}@${readingsIP}" \
        "ss -ltn | grep -w '127.0.0.1:${remoteport}' &>/dev/null && echo open || echo closed" 2>/dev/null)
    [[ "$status" == "open" ]]
}

# Check SIM connection status.
# Now returns 0 if already connected, or 1 after attempting a restart.
check_sim_connection() {
    echo "Checking SIM connection"
    if cell_mgmt status | grep -q "Status: connected"; then
        return 0
    else
        log "Cell connection lost, restarting..."
        /usr/local/bin/cell_mgmt_startup.sh
        return 1
    fi
}

# Main loop to keep the SSH tunnel alive.
while true; do
    # If using SIM, check the connection and wait before proceeding.
    if [[ "$USES_CELL" -eq 1 ]]; then
        # Only skip the rest of the loop if we just restarted the SIM.
        if ! check_sim_connection; then
            sleep 100
            continue
        fi
        # otherwise, SIM is up – fall through to the tunnel logic
    fi

    retrieve_remote_port

    if ! is_ssh_tunnel_alive; then
        echo "SSH tunnel is down, restarting..."
        log "SSH tunnel is down, restarting..."
        if ! restart_ssh_tunnel; then
            echo "Tunnel restart failed, retrying in 100s."
            log "Tunnel restart failed, retrying in 100s."
            sleep 100
            continue
        fi
    fi

    if ! is_remote_port_listening; then
        echo "Remote port $remoteport is not listening, restarting tunnel..."
        log "Remote port $remoteport is not listening, restarting tunnel..."
        if ! restart_ssh_tunnel; then
            echo "Tunnel restart failed, retrying in 100s."
            log "Tunnel restart failed, retrying in 100s."
            sleep 100
            continue
        fi
    fi

    echo "Tunnel is up and remote port is listening."
    sleep 100
done
