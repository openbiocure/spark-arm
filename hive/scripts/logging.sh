#!/bin/bash

# Logging functions for Hive scripts
# Usage: source /opt/hive/bin/logging.sh

# Initialize logging
init_logging() {
    # Determine if we're in installation mode or runtime mode
    if [ -f "/tmp/install-hadoop.sh" ]; then
        # Installation mode - use /tmp
        export LOG_FILE="/tmp/hive-install.log"
    else
        # Runtime mode - use Hive logs directory
        export LOG_FILE="${HIVE_HOME}/logs/hive.log"
    fi

    # Remove existing log file if it exists as we don't have write permission
    if [ -f "$LOG_FILE" ] && [ ! -w "$LOG_FILE" ]; then
        rm -f "$LOG_FILE"
    fi

    # Create log file with proper permissions
    touch "$LOG_FILE" 2>/dev/null || true
    chmod 666 "$LOG_FILE" 2>/dev/null || true
}

# Log levels
log_info() {
    if [ -w "$LOG_FILE" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" | tee -a "$LOG_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
    fi
}

log_warn() {
    if [ -w "$LOG_FILE" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $1" | tee -a "$LOG_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $1"
    fi
}

log_error() {
    if [ -w "$LOG_FILE" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" | tee -a "$LOG_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
    fi
}

# Error handler
handle_error() {
    local script=$1
    local line=$2
    local exit_code=$3
    
    log_error "Error in $script at line $line (exit code: $exit_code)"
    exit "$exit_code"
} 