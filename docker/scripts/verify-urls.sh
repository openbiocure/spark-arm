#!/bin/bash
set -ex

# Basic string trim function that works in any shell
trim() {
    local var="$*"
    # remove leading whitespace
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace
    var="${var%"${var##*[![:space:]]}"}"
    # remove any carriage returns or newlines
    var="${var//[$'\r\n']}"
    printf '%s' "$var"
}

# Function to verify a URL
verify_url() {
    local url=$1
    local name=$2
    # Trim any whitespace from the URL using basic shell functions
    url=$(trim "$url")
    
    # Check if URL is empty
    if [ -z "$url" ]; then
        echo "ERROR: $name URL is empty"
        exit 1
    fi
    
    echo "Checking $name URL: $url"
    # Try the verification with verbose output
    if ! curl --head --silent --fail --show-error "$url" > /dev/null 2>&1; then
        echo "ERROR: $name URL is not accessible: $url"
        # Try with verbose output to see what's happening
        echo "Detailed error information:"
        curl --head --verbose "$url" 2>&1 || true
        exit 1
    fi
    echo "✓ $name URL verified"
}

# Print environment variables for debugging
echo "Environment variables:"
echo "SPARK_URL_TEMPLATE: '$SPARK_URL_TEMPLATE'"
echo "HADOOP_URL_TEMPLATE: '$HADOOP_URL_TEMPLATE'"
echo "DELTA_CORE_URL_TEMPLATE: '$DELTA_CORE_URL_TEMPLATE'"
echo "DELTA_SPARK_URL_TEMPLATE: '$DELTA_SPARK_URL_TEMPLATE'"
echo "AWS_BUNDLE_URL_TEMPLATE: '$AWS_BUNDLE_URL_TEMPLATE'"
echo "AWS_S3_URL_TEMPLATE: '$AWS_S3_URL_TEMPLATE'"
echo "HADOOP_AWS_URL_TEMPLATE: '$HADOOP_AWS_URL_TEMPLATE'"

# Verify all URLs
echo "Verifying download URLs..."
verify_url "$SPARK_URL_TEMPLATE" "Spark"
verify_url "$HADOOP_URL_TEMPLATE" "Hadoop"
verify_url "$DELTA_CORE_URL_TEMPLATE" "Delta Core"
verify_url "$DELTA_SPARK_URL_TEMPLATE" "Delta Spark"
verify_url "$AWS_BUNDLE_URL_TEMPLATE" "AWS SDK Bundle"
verify_url "$AWS_S3_URL_TEMPLATE" "AWS SDK S3"
verify_url "$HADOOP_AWS_URL_TEMPLATE" "Hadoop AWS"

echo "All URLs verified successfully!" 