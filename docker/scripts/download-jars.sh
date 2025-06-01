#!/bin/bash
set -euo pipefail

# Source the versions file
source /opt/spark/scripts/versions.sh

# Source the logging library
source /opt/spark/scripts/logging.sh

# Initialize logging
init_logging

# Function to download a single JAR
download_jar() {
    local url=$1
    local output_dir=$2
    local filename=$(basename "$url")
    local output_path="${output_dir}/${filename}"
    
    log_info "Downloading ${filename}..."
    if curl -L -f -o "${output_path}" "${url}"; then
        log_info "✓ Downloaded ${filename}"
        return 0
    else
        log_error "Failed to download ${filename}"
        return 1
    fi
}

# Function to download JARs in parallel
download_jars_parallel() {
    local output_dir=$1
    shift
    local urls=("$@")
    local pids=()
    local failed=0
    
    # Create output directory if it doesn't exist
    mkdir -p "${output_dir}"
    
    # Start downloads in parallel
    for url in "${urls[@]}"; do
        download_jar "${url}" "${output_dir}" &
        pids+=($!)
    done
    
    # Wait for all downloads to complete
    for pid in "${pids[@]}"; do
        if ! wait "${pid}"; then
            failed=1
        fi
    done
    
    return ${failed}
}

# Main function to download all required JARs
download_all_jars() {
    log_info "=== Downloading Required JARs ==="
    
    # Create jars directory if it doesn't exist
    mkdir -p "${SPARK_HOME}/jars"
    
    # List of JARs to download
    local urls=(
        "${DELTA_CORE_URL_TEMPLATE}"
        "${DELTA_SPARK_URL_TEMPLATE}"
        "${AWS_BUNDLE_URL_TEMPLATE}"
        "${AWS_S3_URL_TEMPLATE}"
        "${HADOOP_AWS_URL_TEMPLATE}"
    )
    
    # Download JARs in parallel
    if ! download_jars_parallel "${SPARK_HOME}/jars" "${urls[@]}"; then
        log_error "Failed to download one or more JARs"
        return 1
    fi
    
    log_info "All JARs downloaded successfully"
    return 0
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    download_all_jars
fi 