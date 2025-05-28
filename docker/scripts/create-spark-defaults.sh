#!/bin/bash
set -e
cat<<EOF > ${SPARK_HOME}/conf/spark-defaults.conf
spark.driver.extraClassPath /opt/spark/jars/*
spark.executor.extraClassPath /opt/spark/jars/*
spark.sql.extensions io.delta.sql.DeltaSparkSessionExtension
spark.sql.catalog.spark_catalog org.apache.spark.sql.delta.catalog.DeltaCatalog
EOF