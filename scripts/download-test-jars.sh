#!/bin/bash

set -e

# Target folder
JARS_DIR="$HOME/spark-jars"
mkdir -p "$JARS_DIR"

# Versions
HIVE_VERSION=2.3.9
HADOOP_VERSION=3.3.6
AWS_SDK_VERSION=1.12.262
SCALA_VERSION=2.13
SPARK_VERSION=3.5.5
POSTGRES_VERSION=42.7.3

echo "📦 Downloading required JARs to $JARS_DIR"

# Hive JARs
curl -L -o $JARS_DIR/hive-common-$HIVE_VERSION.jar         https://repo1.maven.org/maven2/org/apache/hive/hive-common/$HIVE_VERSION/hive-common-$HIVE_VERSION.jar
curl -L -o $JARS_DIR/hive-cli-$HIVE_VERSION.jar            https://repo1.maven.org/maven2/org/apache/hive/hive-cli/$HIVE_VERSION/hive-cli-$HIVE_VERSION.jar
curl -L -o $JARS_DIR/hive-metastore-$HIVE_VERSION.jar      https://repo1.maven.org/maven2/org/apache/hive/hive-metastore/$HIVE_VERSION/hive-metastore-$HIVE_VERSION.jar
curl -L -o $JARS_DIR/hive-exec-$HIVE_VERSION-core.jar      https://repo1.maven.org/maven2/org/apache/hive/hive-exec/$HIVE_VERSION/hive-exec-$HIVE_VERSION-core.jar
curl -L -o $JARS_DIR/hive-serde-$HIVE_VERSION.jar          https://repo1.maven.org/maven2/org/apache/hive/hive-serde/$HIVE_VERSION/hive-serde-$HIVE_VERSION.jar
curl -L -o $JARS_DIR/hive-jdbc-$HIVE_VERSION.jar           https://repo1.maven.org/maven2/org/apache/hive/hive-jdbc/$HIVE_VERSION/hive-jdbc-$HIVE_VERSION.jar

# Hadoop-AWS and AWS SDK JARs
curl -L -o $JARS_DIR/hadoop-aws-$HADOOP_VERSION.jar        https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/$HADOOP_VERSION/hadoop-aws-$HADOOP_VERSION.jar
curl -L -o $JARS_DIR/aws-java-sdk-bundle-$AWS_SDK_VERSION.jar https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/$AWS_SDK_VERSION/aws-java-sdk-bundle-$AWS_SDK_VERSION.jar

# PostgreSQL JDBC driver
curl -L -o $JARS_DIR/postgresql-$POSTGRES_VERSION.jar      https://repo1.maven.org/maven2/org/postgresql/postgresql/$POSTGRES_VERSION/postgresql-$POSTGRES_VERSION.jar

echo "✅ Done. All JARs are in $JARS_DIR" 