#!/bin/bash
set -e

cat > ${SPARK_HOME}/conf/spark-defaults.conf << EOF
spark.driver.extraClassPath /opt/spark/jars/*
spark.executor.extraClassPath /opt/spark/jars/*
spark.sql.extensions io.delta.sql.DeltaSparkSessionExtension
spark.sql.catalog.spark_catalog org.apache.spark.sql.delta.catalog.DeltaCatalog
EOF 