#!/bin/bash
set -e

create_spark_defaults() {
    local spark_home="${1:-${SPARK_HOME}}"
    log_info "Creating spark-defaults.conf in ${spark_home}/conf/"
    
    cat << 'EOF' > "${spark_home}/conf/spark-defaults.conf"
# Classpath configuration
spark.driver.extraClassPath /opt/spark/jars/*
spark.executor.extraClassPath /opt/spark/jars/*

# Delta Lake configuration
spark.sql.extensions io.delta.sql.DeltaSparkSessionExtension
spark.sql.catalog.spark_catalog org.apache.spark.sql.delta.catalog.DeltaCatalog

# Resource Management
spark.dynamicAllocation.enabled true
spark.dynamicAllocation.minExecutors 1
spark.dynamicAllocation.maxExecutors 10
spark.dynamicAllocation.initialExecutors 1

# Memory Management
spark.memory.fraction 0.8
spark.memory.storageFraction 0.5

# Logging
spark.eventLog.enabled true
spark.eventLog.dir /opt/spark/logs/events

# UI Configuration
spark.ui.port 4041
EOF

    log_info "Created spark-defaults.conf successfully"
}

# Source logging if available
if [ -f "${SPARK_HOME}/scripts/logging.sh" ]; then
    source "${SPARK_HOME}/scripts/logging.sh"
    init_logging
fi

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    create_spark_defaults "$@"
fi