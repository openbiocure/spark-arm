#!/bin/sh
set -e

# Basic string trim function that works in any shell
trim() {
    local var="$*"
    # remove leading whitespace
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

# Function to verify a URL
verify_url() {
    local url=$1
    local name=$2
    # Trim any whitespace from the URL using basic shell functions
    url=$(trim "$url")
    
    # Try the verification
    if ! curl --head --silent --fail "$url" > /dev/null; then
        echo "ERROR: $name URL is not accessible: $url"
        exit 1
    fi
    echo "✓ $name URL verified"
}

# Verify all URLs
echo "Verifying download URLs..."
verify_url "$SPARK_URL_TEMPLATE" "Spark"
verify_url "$HADOOP_URL_TEMPLATE" "Hadoop"
verify_url "$DELTA_URL_TEMPLATE" "Delta Lake"
verify_url "$AWS_BUNDLE_URL_TEMPLATE" "AWS SDK Bundle"
verify_url "$AWS_S3_URL_TEMPLATE" "AWS SDK S3"

echo "All URLs verified successfully!" 