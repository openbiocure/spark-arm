#!/bin/bash
docker run -it --rm \
  -p 10000:10000 \
  -e HIVE_METASTORE_DB_HOST=<postgres-host> \
  -e HIVE_METASTORE_DB_PORT=5432 \
  -e HIVE_METASTORE_DB_NAME=hive \
  -e HIVE_METASTORE_DB_USER=hive \
  -e HIVE_METASTORE_DB_PASSWORD=hive \
  -e HIVE_METASTORE_HOST=localhost \
  -e HIVE_METASTORE_PORT=9083 \
  -e HIVE_SERVER2_BIND_HOST=0.0.0.0 \
  -e HIVE_SERVER2_PORT=10000 \
  -e HIVE_WAREHOUSE_DIR=file:///opt/hive/warehouse \
  -e HIVE_SCRATCH_DIR=/tmp/hive \
  -e AWS_ACCESS_KEY_ID=<access-key> \
  -e AWS_SECRET_ACCESS_KEY=<secret-key> \
  -e AWS_ENDPOINT_URL=http://<minio-host>:9000 \
  -e AWS_DEFAULT_REGION=us-east-1 \
  -e HADOOP_OPTS="-Dfs.s3a.aws.credentials.provider=com.amazonaws.auth.DefaultAWSCredentialsProviderChain \
                  -Dfs.s3a.endpoint=http://<minio-host>:9000 \
                  -Dfs.s3a.path.style.access=true" \
  hive-arm:v0.6.1 /opt/hive/bin/start-hive.sh