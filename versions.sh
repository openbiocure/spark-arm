#!/bin/bash

# Set mirror URL based on hostname
if [ "$(hostname)" = "workernode04" ]; then
    LOCAL_MIRROR_URL="http://mirror.lab/mirror"
else
    LOCAL_MIRROR_URL=""
fi

# Function to evaluate and return expanded values
get_versions() {
    # Core versions
    local SPARK_VERSION="4.0.0"
    local HADOOP_VERSION="3.3.6"
    local DELTA_VERSION="3.3.2"  # Updated to match delta-spark version
    local HIVE_VERSION="3.0.0"
    local POSTGRES_VERSION="42.7.3"
    local AWS_SDK_VERSION="1.12.262"
    local SCALA_VERSION="2.12"  # Changed to 2.12 for Spark 4.0.0

    # Evaluate URL templates with expanded versions
    # Spark and Hadoop
    if [ -n "${LOCAL_MIRROR_URL}" ]; then
        local SPARK_URL="${LOCAL_MIRROR_URL}/spark-${SPARK_VERSION}-bin-hadoop3.tgz"
        local HADOOP_URL="${LOCAL_MIRROR_URL}/hadoop-${HADOOP_VERSION}.tar.gz"
    else
        local SPARK_URL="https://dlcdn.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz"
        local HADOOP_URL="https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz"
    fi

    # Delta Lake
    local DELTA_CORE_URL="https://repo1.maven.org/maven2/io/delta/delta-core_${SCALA_VERSION}/2.4.0/delta-core_${SCALA_VERSION}-2.4.0.jar"
    local DELTA_SPARK_URL="https://repo1.maven.org/maven2/io/delta/delta-spark_${SCALA_VERSION}/${DELTA_VERSION}/delta-spark_${SCALA_VERSION}-${DELTA_VERSION}.jar"

    # Hive
    local HIVE_URL="https://dlcdn.apache.org/hive/hive-standalone-metastore-${HIVE_VERSION}/hive-standalone-metastore-${HIVE_VERSION}-bin.tar.gz"

    # Database
    local POSTGRES_URL="https://repo1.maven.org/maven2/org/postgresql/postgresql/${POSTGRES_VERSION}/postgresql-${POSTGRES_VERSION}.jar"

    # AWS
    local AWS_BUNDLE_URL="https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_SDK_VERSION}/aws-java-sdk-bundle-${AWS_SDK_VERSION}.jar"
    local AWS_S3_URL="https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-s3/${AWS_SDK_VERSION}/aws-java-sdk-s3-${AWS_SDK_VERSION}.jar"
    local HADOOP_AWS_URL="https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_VERSION}/hadoop-aws-${HADOOP_VERSION}.jar"

    # Return as key=value pairs
    cat << EOF
# Core versions
SPARK_VERSION=${SPARK_VERSION}
HADOOP_VERSION=${HADOOP_VERSION}
DELTA_VERSION=${DELTA_VERSION}
HIVE_VERSION=${HIVE_VERSION}
POSTGRES_VERSION=${POSTGRES_VERSION}
AWS_SDK_VERSION=${AWS_SDK_VERSION}
SCALA_VERSION=${SCALA_VERSION}

# URLs
SPARK_URL_TEMPLATE=${SPARK_URL}
HADOOP_URL_TEMPLATE=${HADOOP_URL}
DELTA_CORE_URL_TEMPLATE=${DELTA_CORE_URL}
DELTA_SPARK_URL_TEMPLATE=${DELTA_SPARK_URL}
HIVE_URL_TEMPLATE=${HIVE_URL}
POSTGRES_URL_TEMPLATE=${POSTGRES_URL}
AWS_BUNDLE_URL_TEMPLATE=${AWS_BUNDLE_URL}
AWS_S3_URL_TEMPLATE=${AWS_S3_URL}
HADOOP_AWS_URL_TEMPLATE=${HADOOP_AWS_URL}
EOF
}

# If script is sourced, export the function
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f get_versions
else
    # If script is run directly, output the versions
    get_versions
fi 