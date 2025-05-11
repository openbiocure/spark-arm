#!/bin/bash
set -euo pipefail

# Source the logging library
source /opt/spark/scripts/logging.sh

# Initialize logging
init_logging

# Function to download and verify JARs
download_and_verify_jar() {
    local url=$1
    local output=$2
    local expected_size=${3:-0}
    
    log_info "Downloading $url to $output"
    if curl -fSL "$url" -o "$output"; then
        if [ -f "$output" ]; then
            local actual_size=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output" 2>/dev/null)
            if [ "$actual_size" -gt 0 ]; then
                log_info "Successfully downloaded $(basename $output) ($actual_size bytes)"
                return 0
            fi
        fi
    fi
    log_error "Failed to download or verify $url"
    return 1
}

# Download Delta Lake JARs
download_delta_jars() {
    local spark_home=$1
    local delta_version=$2
    local scala_version=$3
    
    log_info "=== Downloading Delta Lake JARs ==="
    
    # Core Delta Lake JARs
    local delta_jars=(
        # Core components
        "delta-core_${scala_version}/${delta_version}/delta-core_${scala_version}-${delta_version}.jar"
        "delta-storage/${delta_version}/delta-storage-${delta_version}.jar"
        
        # Spark integration
        "delta-spark_${scala_version}/${delta_version}/delta-spark_${scala_version}-${delta_version}.jar"
        "delta-standalone_${scala_version}/${delta_version}/delta-standalone_${scala_version}-${delta_version}.jar"
        "delta-contribs_${scala_version}/${delta_version}/delta-contribs_${scala_version}-${delta_version}.jar"
        
        # Hive integration
        "delta-hive_${scala_version}/${delta_version}/delta-hive_${scala_version}-${delta_version}.jar"
    )
    
    for jar in "${delta_jars[@]}"; do
        log_info "Attempting to download: $jar"
        download_and_verify_jar \
            "https://repo1.maven.org/maven2/io/delta/${jar}" \
            "${spark_home}/jars/$(basename $jar)" || {
                log_error "Failed to download $jar"
                exit 1
            }
    done
}

# Download Hadoop AWS and AWS SDK JARs
download_hadoop_aws_jars() {
    local spark_home=$1
    local hadoop_version=$2
    local aws_sdk_version=$3
    
    log_info "=== Downloading Hadoop AWS and AWS SDK JARs ==="
    
    # Download Hadoop AWS JARs
    download_and_verify_jar \
        "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${hadoop_version}/hadoop-aws-${hadoop_version}.jar" \
        "${spark_home}/jars/hadoop-aws-${hadoop_version}.jar" || exit 1
    
    download_and_verify_jar \
        "https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${aws_sdk_version}/aws-java-sdk-bundle-${aws_sdk_version}.jar" \
        "${spark_home}/jars/aws-java-sdk-bundle-${aws_sdk_version}.jar" || exit 1
    
    download_and_verify_jar \
        "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-common/${hadoop_version}/hadoop-common-${hadoop_version}.jar" \
        "${spark_home}/jars/hadoop-common-${hadoop_version}.jar" || exit 1
    
    download_and_verify_jar \
        "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-client/${hadoop_version}/hadoop-client-${hadoop_version}.jar" \
        "${spark_home}/jars/hadoop-client-${hadoop_version}.jar" || exit 1
}

# Verify JARs are present
verify_jars() {
    local spark_home=$1
    
    log_info "=== Verifying JARs ==="
    
    log_info "Delta Lake JARs:"
    ls -l ${spark_home}/jars/delta-*.jar || log_error "No Delta Lake JARs found"
    
    log_info "Hadoop AWS JARs:"
    ls -l ${spark_home}/jars/hadoop-*.jar || log_error "No Hadoop AWS JARs found"
    
    log_info "AWS SDK JARs:"
    ls -l ${spark_home}/jars/aws-*.jar || log_error "No AWS SDK JARs found"
}

# Main function to download all JARs
download_all_jars() {
    local spark_home=${SPARK_HOME:-/opt/spark}
    local delta_version=${DELTA_VERSION:-3.3.1}
    local hadoop_version=${HADOOP_VERSION:-3.3.6}
    local aws_sdk_version=${AWS_SDK_VERSION:-1.12.262}
    local scala_version=${SCALA_VERSION:-2.13}
    
    # Create jars directory if it doesn't exist
    mkdir -p "${spark_home}/jars"
    
    # Download all JARs
    download_delta_jars "$spark_home" "$delta_version" "$scala_version"
    download_hadoop_aws_jars "$spark_home" "$hadoop_version" "$aws_sdk_version"
    
    # Verify all JARs
    verify_jars "$spark_home"
}

# If script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    download_all_jars
fi 