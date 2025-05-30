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

# Function to download and install Hadoop native libraries
download_and_install_hadoop_native() {
    local hadoop_version=$1
    local hadoop_home=$2
    local max_attempts=3
    local attempt=1
    
    log_info "Starting Hadoop native libraries download process for version ${hadoop_version}"
    
    # Create native libraries directory
    log_info "Creating native libraries directory..."
    mkdir -p ${hadoop_home}/lib/native
    
    # For ARM64, we'll use the pre-built native libraries from the Hadoop distribution
    # The native libraries are platform-independent for basic operations
    local hadoop_url="https://dlcdn.apache.org/hadoop/common/hadoop-${hadoop_version}/hadoop-${hadoop_version}.tar.gz"
    
    # Verify URL exists before attempting download
    if ! verify_url "$hadoop_url"; then
        log_error "Hadoop version ${hadoop_version} is not available at the expected URL"
        return 1
    fi
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Attempt ${attempt} of ${max_attempts} to download Hadoop..."
        
        if curl -fSL --retry 3 --retry-delay 5 \
            "$hadoop_url" \
            -o /tmp/hadoop.tar.gz; then
            
            log_info "Download successful"
            
            # Verify download
            log_info "Verifying download..."
            local file_size=$(stat -f%z /tmp/hadoop.tar.gz 2>/dev/null || stat -c%s /tmp/hadoop.tar.gz 2>/dev/null)
            log_info "Downloaded file size: ${file_size} bytes"
            
            if [ "$file_size" -lt 1000000 ]; then
                log_error "Downloaded file seems too small (${file_size} bytes)"
                rm -f /tmp/hadoop.tar.gz
                attempt=$((attempt + 1))
                continue
            fi
            
            # Extract and install
            log_info "Extracting Hadoop archive..."
            tar -xf /tmp/hadoop.tar.gz -C /tmp
            
            log_info "Copying native libraries..."
            # Copy only the necessary native libraries
            cp -r /tmp/hadoop-${hadoop_version}/lib/native/* ${hadoop_home}/lib/native/
            
            # Set environment variable to disable native code loading
            echo "export HADOOP_OPTS=\"-Djava.library.path=${hadoop_home}/lib/native\"" >> /etc/profile.d/hadoop.sh
            chmod +x /etc/profile.d/hadoop.sh
            
            log_info "Cleaning up..."
            rm -rf /tmp/hadoop.tar.gz /tmp/hadoop-${hadoop_version}
            
            log_info "Hadoop native libraries installation completed successfully"
            return 0
        else
            log_error "Download failed on attempt ${attempt}"
            rm -f /tmp/hadoop.tar.gz
            
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
        echo "Usage: $0 <hadoop_version> <hadoop_home>"
        exit 1
    fi
    
    download_and_install_hadoop_native "$1" "$2"
fi 