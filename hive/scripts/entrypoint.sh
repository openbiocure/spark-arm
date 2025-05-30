#!/bin/bash
set -e

# Source the logging and metastore check functions
source $HIVE_HOME/scripts/logging.sh
source $HIVE_HOME/scripts/metastore-check.sh

# Initialize logging
init_logging

# Script Version
log_info "Script Version: 1.3.0"

# Verify Hadoop installation
log_info "Verifying Hadoop installation:"
log_info "HADOOP_HOME: $HADOOP_HOME"
ls -la $HADOOP_HOME
log_info "Hadoop version:"
$HADOOP_HOME/bin/hadoop version

# Verify Hive installation
log_info "Verifying Hive installation:"
log_info "HIVE_HOME: $HIVE_HOME"
ls -la $HIVE_HOME/bin
log_info "Hive metastore scripts available:"
ls -l $HIVE_HOME/bin/metastore-config.sh $HIVE_HOME/bin/start-metastore $HIVE_HOME/bin/schematool
log_info "Checking for metastore JAR:"
ls -l $HIVE_HOME/lib/hive-standalone-metastore-*.jar || log_warn "No standalone metastore JAR found"

# Required environment variables
required_vars=(
    "HIVE_METASTORE_DB_HOST"
    "HIVE_METASTORE_DB_PORT"
    "HIVE_METASTORE_DB_NAME"
    "HIVE_METASTORE_DB_USER"
    "HIVE_METASTORE_DB_PASSWORD"
    "HIVE_WAREHOUSE_DIR"
    "HIVE_SCRATCH_DIR"
)

# Check required environment variables
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        log_error "Required environment variable $var is not set"
        exit 1
    fi
done

# Set default values for optional variables
export HIVE_METASTORE_URI=${HIVE_METASTORE_URI:-"thrift://0.0.0.0:9083"}

# Ensure directories exist and have correct permissions
mkdir -p ${HIVE_WAREHOUSE_DIR}
mkdir -p ${HIVE_SCRATCH_DIR}
mkdir -p ${HIVE_HOME}/logs

# Render hive-site.xml from template
log_info "Rendering hive-site.xml from template..."

# Create the file
envsubst < $HIVE_HOME/conf/hive-site.xml.template > $HIVE_HOME/conf/hive-site.xml

# Check if template exists (in case envsubst failed)
if [ ! -f "$HIVE_HOME/conf/hive-site.xml.template" ]; then
    log_error "Template file not found: $HIVE_HOME/conf/hive-site.xml.template"
    log_error "Contents of $HIVE_HOME/conf/:"
    ls -la $HIVE_HOME/conf/
    exit 1
fi

# Verify the file was created
if [ ! -f "$HIVE_HOME/conf/hive-site.xml" ]; then
    log_error "Failed to create hive-site.xml"
    exit 1
fi

log_info "Successfully created hive-site.xml"
log_info "Contents of $HIVE_HOME/conf/:"
ls -la $HIVE_HOME/conf/

# Initialize schema if needed
log_info "Checking if schema initialization is needed..."
if ! $HIVE_HOME/bin/schematool -dbType postgres -info; then
    log_info "Initializing schema..."
    $HIVE_HOME/bin/schematool -initSchema -dbType postgres
fi

# Set up HADOOP_CLASSPATH with absolute paths
export HADOOP_CLASSPATH=/opt/hive/conf:/opt/hive/lib/*:/opt/hadoop/share/hadoop/common/*:/opt/hadoop/share/hadoop/common/lib/*:/opt/hive/lib/postgresql-42.7.3.jar

# Start metastore service
log_info "Starting Hive Metastore service..."

nohup java -cp "$HADOOP_CLASSPATH" \
  -Dlog4j.configurationFile=${HIVE_HOME}/conf/log4j2.xml \
  -Dhive.log.dir=${HIVE_HOME}/logs \
  -Dhive.log.file=hive.log \
  -Dhive.log.level=DEBUG \
  -Dhadoop.home.dir=/opt/hadoop \
  org.apache.hadoop.hive.metastore.HiveMetaStore \
  -dbType postgres \
  > ${HIVE_HOME}/logs/metastore.out 2>&1 &

# Store the process ID and check startup
METASTORE_PID=$!
if ! check_metastore_startup $METASTORE_PID; then
    log_error "Hive Metastore failed to start properly. Please check the logs above for details."
    log_error "You can find the full logs at: ${HIVE_HOME}/logs/metastore.out"
    log_error "Last few lines of metastore log:"
    log_error "----------------------------------------"
    tail -n 20 ${HIVE_HOME}/logs/metastore.out
    log_error "----------------------------------------"
    exit 1
fi

# Keep container running
log_info "Metastore started successfully. Following logs..."
tail -f $HIVE_HOME/logs/hive.log 