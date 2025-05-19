# syntax=docker/dockerfile:1.4

# Use the same base image as Spark for consistency
FROM eclipse-temurin:17-jdk-jammy

# Define build arguments
ARG HADOOP_VERSION
ARG HIVE_VERSION
ARG POSTGRES_VERSION

# Set environment variables
ENV HADOOP_HOME=/opt/hadoop \
    HIVE_HOME=/opt/hive \
    PATH=/opt/hadoop/bin:/opt/hive/bin:$PATH \
    LOG_FILE=/tmp/hive-install.log

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    procps \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p ${HADOOP_HOME} ${HIVE_HOME}/logs \
    && groupadd -r hive && useradd -r -g hive hive \
    && chown -R hive:hive ${HADOOP_HOME} ${HIVE_HOME} \
    && chmod 755 ${HADOOP_HOME} ${HIVE_HOME} \
    && chmod 777 ${HIVE_HOME}/logs

# Copy installation scripts
COPY scripts/logging.sh scripts/install-hadoop.sh scripts/install-hive.sh /tmp/
RUN chmod +x /tmp/*.sh

# Install Hadoop and Hive
RUN . /tmp/logging.sh && init_logging && \
    /tmp/install-hadoop.sh ${HADOOP_VERSION} ${HADOOP_HOME} && \
    /tmp/install-hive.sh ${HIVE_VERSION} ${HIVE_HOME}

# Copy configuration files
COPY conf/hive-site.xml ${HIVE_HOME}/conf/
COPY conf/core-site.xml ${HADOOP_HOME}/etc/hadoop/
COPY conf/hdfs-site.xml ${HADOOP_HOME}/etc/hadoop/

# Copy startup scripts and logging
COPY scripts/start-hive.sh scripts/logging.sh ${HIVE_HOME}/bin/
RUN chmod +x ${HIVE_HOME}/bin/*.sh

# Set working directory
WORKDIR ${HIVE_HOME}

# Use hive user
USER hive

# Default command
CMD ["/opt/hive/bin/start-hive.sh"] 