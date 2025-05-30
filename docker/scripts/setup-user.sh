#!/bin/bash
set -euo pipefail

# Source the logging library
source /opt/spark/scripts/logging.sh

# Initialize logging
init_logging

# Function to set up the spark user and required directories
setup_spark_user() {
    log_info "Setting up spark user and directories..."
    
    # Create user and group
    groupadd -g 1000 spark || log_warn "Group spark already exists"
    useradd -u 1000 -g spark -m -d /home/spark -s /bin/bash spark || log_warn "User spark already exists"
    
    # Create directories with proper permissions
    mkdir -p ${SPARK_HOME} ${HADOOP_HOME}/lib/native ${SPARK_HOME}/jars ${SPARK_HOME}/logs ${SPARK_HOME}/tmp
    
    # Set ownership of all directories
    chown -R spark:spark ${SPARK_HOME} ${HADOOP_HOME} /home/spark
    
    # Set permissions for directories
    chmod 755 ${SPARK_HOME} ${HADOOP_HOME} /home/spark
    
    # Ensure spark user has access to essential commands
    chmod -R 755 /usr/bin/bash /usr/bin/date /usr/bin/mkdir
    
    # Ensure spark user can write to /opt/spark
    chown -R spark:spark /opt/spark
    chmod -R 755 /opt/spark
    
    # Create proper passwd and group entries while preserving root
    cat > /etc/passwd << 'EOF'
root:x:0:0:root:/root:/bin/bash
spark:x:1000:1000:Spark User:/home/spark:/bin/bash
EOF

    cat > /etc/group << 'EOF'
root:x:0:
spark:x:1000:
EOF
    
    # Verify essential commands are available and accessible
    su - spark -c "which bash" || log_error "bash not available for spark user"
    su - spark -c "which date" || log_error "date not available for spark user"
    su - spark -c "which mkdir" || log_error "mkdir not available for spark user"
    
    # Verify directories are accessible
    su - spark -c "test -w ${SPARK_HOME}/logs" || log_error "spark user cannot write to logs directory"
    su - spark -c "test -w ${SPARK_HOME}/tmp" || log_error "spark user cannot write to tmp directory"
    su - spark -c "test -w /opt/spark" || log_error "spark user cannot write to /opt/spark"
    
    log_info "Spark user setup completed successfully"
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_spark_user
fi