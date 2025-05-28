#!/bin/bash
set -e

create_spark_defaults() {
    local spark_home="${1:-${SPARK_HOME}}"
    log_info "Creating spark-defaults.conf in ${spark_home}/conf/"
    
    cat << 'EOF' > "${spark_home}/conf/spark-defaults.conf"
spark.driver.extraClassPath /opt/spark/jars/*
spark.executor.extraClassPath /opt/spark/jars/*
spark.sql.extensions io.delta.sql.DeltaSparkSessionExtension
spark.sql.catalog.spark_catalog org.apache.spark.sql.delta.catalog.DeltaCatalog
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