#!/bin/bash
set -euo pipefail

# Source logging if available
if [ -f "${SPARK_HOME}/scripts/logging.sh" ]; then
    source "${SPARK_HOME}/scripts/logging.sh"
    init_logging
else
    # Basic logging functions if not available
    log_info() { echo "[INFO] $1"; }
    log_error() { echo "[ERROR] $1"; exit 1; }
    log_warn() { echo "[WARN] $1"; }
fi

# Configuration
HADOOP_VERSION="${1:-3.3.6}"
HADOOP_HOME="${2:-/opt/hadoop}"
DOWNLOAD_DIR="/tmp/downloads"
REQUIRED_TOOLS=("curl" "tar")

# Function to check required tools
check_requirements() {
    log_info "Checking requirements..."
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_error "$tool is required but not installed"
        fi
    done
}

# Function to download and install Hadoop
install_hadoop() {
    log_info "Installing Hadoop ${HADOOP_VERSION}..."
    
    # Create directories
    mkdir -p "${DOWNLOAD_DIR}"
    mkdir -p "${HADOOP_HOME}"
    
    # Download Hadoop
    local hadoop_url="${HADOOP_URL_TEMPLATE}"
    local hadoop_archive="${DOWNLOAD_DIR}/hadoop-${HADOOP_VERSION}.tar.gz"
    
    log_info "Downloading Hadoop from ${hadoop_url}..."
    if ! curl -L "${hadoop_url}" -o "${hadoop_archive}"; then
        log_error "Failed to download Hadoop"
    fi
    
    # Extract Hadoop
    log_info "Extracting Hadoop..."
    tar -xzf "${hadoop_archive}" -C "${DOWNLOAD_DIR}"
    
    # Move files to HADOOP_HOME
    log_info "Installing Hadoop to ${HADOOP_HOME}..."
    cp -r "${DOWNLOAD_DIR}/hadoop-${HADOOP_VERSION}"/* "${HADOOP_HOME}/"
    
    # Clean up
    rm -rf "${DOWNLOAD_DIR}/hadoop-${HADOOP_VERSION}"
    rm -f "${hadoop_archive}"
    
    # Verify installation
    if [ -f "${HADOOP_HOME}/bin/hadoop" ]; then
        log_info "Hadoop installed successfully"
        "${HADOOP_HOME}/bin/hadoop" version
    else
        log_error "Hadoop installation failed"
    fi
}

# Main execution
main() {
    log_info "Starting Hadoop installation"
    log_info "Hadoop version: ${HADOOP_VERSION}"
    log_info "Installation directory: ${HADOOP_HOME}"
    
    check_requirements
    install_hadoop
    
    log_info "Installation completed successfully"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi 