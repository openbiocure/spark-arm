#!/bin/bash

# Function to evaluate and return expanded values
get_versions() {
    # Base versions
    local SPARK_VERSION="3.5.5"
    local HADOOP_VERSION="3.3.6"
    local DELTA_VERSION="3.3.1"
    local AWS_SDK_VERSION="1.12.262"
    local SCALA_VERSION="2.13"
    local HIVE_VERSION="4.0.1"

    # Evaluate URL templates with expanded versions
    local SPARK_URL="https://dlcdn.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3-scala${SCALA_VERSION}.tgz"
    local HADOOP_URL="https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz"
    local DELTA_URL="https://repo1.maven.org/maven2/io/delta/delta-spark_${SCALA_VERSION}/${DELTA_VERSION}/delta-spark_${SCALA_VERSION}-${DELTA_VERSION}.jar"
    local AWS_BUNDLE_URL="https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_SDK_VERSION}/aws-java-sdk-bundle-${AWS_SDK_VERSION}.jar"
    local AWS_S3_URL="https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-s3/${AWS_SDK_VERSION}/aws-java-sdk-s3-${AWS_SDK_VERSION}.jar"
    local HIVE_URL="https://dlcdn.apache.org/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz"

    # Return as key=value pairs
    cat << EOF
SPARK_VERSION=${SPARK_VERSION}
HADOOP_VERSION=${HADOOP_VERSION}
DELTA_VERSION=${DELTA_VERSION}
AWS_SDK_VERSION=${AWS_SDK_VERSION}
SCALA_VERSION=${SCALA_VERSION}
HIVE_VERSION=${HIVE_VERSION}
SPARK_URL_TEMPLATE=${SPARK_URL}
HADOOP_URL_TEMPLATE=${HADOOP_URL}
DELTA_URL_TEMPLATE=${DELTA_URL}
AWS_BUNDLE_URL_TEMPLATE=${AWS_BUNDLE_URL}
AWS_S3_URL_TEMPLATE=${AWS_S3_URL}
HIVE_URL_TEMPLATE=${HIVE_URL}
EOF
}

# If script is sourced, export the function
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f get_versions
else
    # If script is run directly, output the versions
    get_versions
fi 