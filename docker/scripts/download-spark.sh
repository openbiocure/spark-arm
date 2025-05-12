#!/bin/bash
set -euo pipefail

# Source the logging library
source /opt/spark/scripts/logging.sh

# Initialize logging
init_logging

# Function to verify URL exists
verify_url() {
    local url=$1
    log_info "Verifying URL exists: $url"
    if curl -s --head --fail "$url" > /dev/null; then
        log_info "URL exists and is accessible"
        return 0
    else
        log_error "URL does not exist or is not accessible: $url"
        return 1
    fi
}

# Function to download and install Spark
download_and_install_spark() {
    local spark_version=$1
    local spark_home=$2
    local max_attempts=3
    local attempt=1
    
    log_info "Starting Spark download process for version ${spark_version}"
    
    # Construct the download URL
    local spark_url="https://dlcdn.apache.org/spark/spark-${spark_version}/spark-${spark_version}-bin-hadoop3-scala2.13.tgz"
    
    # Verify URL exists before attempting download
    if ! verify_url "$spark_url"; then
        log_error "Spark version ${spark_version} is not available at the expected URL"
        return 1
    fi
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Attempt ${attempt} of ${max_attempts} to download Spark..."
        
        if curl -fSL --retry 3 --retry-delay 5 \
            "$spark_url" \
            -o /tmp/spark.tgz; then
            
            log_info "Download successful"
            
            # Verify download
            log_info "Verifying download..."
            local file_size=$(stat -f%z /tmp/spark.tgz 2>/dev/null || stat -c%s /tmp/spark.tgz 2>/dev/null)
            log_info "Downloaded file size: ${file_size} bytes"
            
            if [ "$file_size" -lt 1000000 ]; then
                log_error "Downloaded file seems too small (${file_size} bytes)"
                rm -f /tmp/spark.tgz
                attempt=$((attempt + 1))
                continue
            fi
            
            # Extract and install
            log_info "Extracting Spark archive..."
            tar -xf /tmp/spark.tgz -C /opt
            
            log_info "Moving files to ${spark_home}..."
            mv /opt/spark-${spark_version}-bin-hadoop3-scala2.13/* "${spark_home}"
            
            log_info "Cleaning up..."
            rm -rf /tmp/spark.tgz /opt/spark-${spark_version}-bin-hadoop3-scala2.13
            
            log_info "Spark installation completed successfully"
            return 0
        else
            log_error "Download failed on attempt ${attempt}"
            rm -f /tmp/spark.tgz
            
            if [ $attempt -eq $max_attempts ]; then
                log_error "All download attempts failed"
                return 1
            fi
            
            log_info "Waiting 5 seconds before next attempt..."
            sleep 5
            attempt=$((attempt + 1))
        fi
    done
    
    return 1
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ "$#" -ne 2 ]; then
        echo "Usage: $0 <spark_version> <spark_home>"
        exit 1
    fi
    
    download_and_install_spark "$1" "$2"
fi 