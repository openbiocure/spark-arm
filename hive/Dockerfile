# Use Eclipse Temurin JDK 17 as base image (supports ARM64)
FROM eclipse-temurin:17-jdk-jammy

# Define build arguments for versions (must be provided during build)
ARG HIVE_VERSION
ARG HADOOP_VERSION
ARG POSTGRES_VERSION

# Set environment variables
ENV HADOOP_HOME=/opt/hadoop \
    HIVE_HOME=/opt/hive \
    PATH=/usr/bin:/usr/local/bin:/opt/hadoop/bin:/opt/hive/bin:$PATH \
    SERVICE_NAME=metastore \
    DB_DRIVER=postgres \
    SERVICE_OPTS="-Djavax.jdo.option.ConnectionDriverName=org.postgresql.Driver \
                  -Djavax.jdo.option.ConnectionURL=jdbc:postgresql://${HIVE_METASTORE_DB_HOST:-postgresql}:${HIVE_METASTORE_DB_PORT:-5432}/${HIVE_METASTORE_DB_NAME:-hive} \
                  -Djavax.jdo.option.ConnectionUserName=${HIVE_METASTORE_DB_USER:-hive} \
                  -Djavax.jdo.option.ConnectionPassword=${HIVE_METASTORE_DB_PASSWORD:-hive}"

# Install required packages and create hive user
RUN apt-get update && apt-get install -y \
    curl \
    procps \
    gettext \
    iproute2 \
    net-tools \
    lsof \
    nano \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -g 1000 hive \
    && useradd -u 1000 -g hive -m -s /bin/bash hive

# Create base directories with correct ownership
RUN mkdir -p /opt && chown hive:hive /opt

# Switch to hive user for remaining operations
USER hive

# Create Hive and Hadoop directories with correct permissions
# Only create and set permissions for directories that need specific access
RUN mkdir -p $HIVE_HOME && \
    mkdir -p $HADOOP_HOME && \
    mkdir -p $HIVE_HOME/conf && \
    mkdir -p $HIVE_HOME/scripts && \
    mkdir -p $HIVE_HOME/warehouse && \
    mkdir -p $HIVE_HOME/scratch && \
    mkdir -p $HIVE_HOME/logs && \
    mkdir -p $HIVE_HOME/tmp && \
    mkdir -p $HIVE_HOME/bin && \
    mkdir -p $HIVE_HOME/lib && \
    chmod 755 $HIVE_HOME && \
    chmod 755 $HADOOP_HOME && \
    chmod 755 $HIVE_HOME/conf && \
    chmod 755 $HIVE_HOME/scripts && \
    chmod 755 $HIVE_HOME/bin && \
    chmod 755 $HIVE_HOME/lib && \
    chmod 750 $HIVE_HOME/warehouse && \
    chmod 750 $HIVE_HOME/scratch && \
    chmod 750 $HIVE_HOME/logs && \
    chmod 750 $HIVE_HOME/tmp

# Switch back to root to copy installation scripts
USER root

# Copy all scripts to their permanent location
COPY --chown=hive:hive scripts/logging.sh $HIVE_HOME/scripts/
COPY --chown=hive:hive scripts/metastore-check.sh $HIVE_HOME/scripts/
COPY --chown=hive:hive scripts/install-hadoop.sh $HIVE_HOME/scripts/
RUN chmod +x $HIVE_HOME/scripts/metastore-check.sh $HIVE_HOME/scripts/install-hadoop.sh

# Switch back to hive user for installation
USER hive

# Install Hadoop using the script
RUN $HIVE_HOME/scripts/install-hadoop.sh ${HADOOP_VERSION} ${HADOOP_HOME}

# Download and extract Hive (as hive user)
RUN curl -L https://dlcdn.apache.org/hive/hive-standalone-metastore-${HIVE_VERSION}/hive-standalone-metastore-${HIVE_VERSION}-bin.tar.gz | \
    tar xz -C /opt/ && \
    # Move everything except scripts directory first
    find /opt/apache-hive-metastore-${HIVE_VERSION}-bin -mindepth 1 -maxdepth 1 -not -name scripts -exec mv {} $HIVE_HOME/ \; && \
    # Move Hive's scripts to a subdirectory
    mv /opt/apache-hive-metastore-${HIVE_VERSION}-bin/scripts $HIVE_HOME/scripts/metastore && \
    rm -rf /opt/apache-hive-metastore-${HIVE_VERSION}-bin && \
    # Download standalone metastore JAR
    curl -L https://repo1.maven.org/maven2/org/apache/hive/hive-standalone-metastore/${HIVE_VERSION}/hive-standalone-metastore-${HIVE_VERSION}.jar \
        -o $HIVE_HOME/lib/hive-standalone-metastore-${HIVE_VERSION}.jar && \
    # Verify and set permissions for Hive binaries
    if [ -f "$HIVE_HOME/bin/metastore-config.sh" ]; then \
        chmod 755 $HIVE_HOME/bin/metastore-config.sh; \
    else \
        echo "Warning: metastore-config.sh not found at $HIVE_HOME/bin/metastore-config.sh"; \
        ls -la $HIVE_HOME/bin/; \
    fi && \
    if [ -f "$HIVE_HOME/bin/schematool" ]; then \
        chmod 755 $HIVE_HOME/bin/schematool; \
    else \
        echo "Warning: schematool not found at $HIVE_HOME/bin/schematool"; \
        ls -la $HIVE_HOME/bin/; \
    fi && \
    if [ -f "$HIVE_HOME/bin/start-metastore" ]; then \
        chmod 755 $HIVE_HOME/bin/start-metastore; \
    else \
        echo "Warning: start-metastore not found at $HIVE_HOME/bin/start-metastore"; \
        ls -la $HIVE_HOME/bin/; \
    fi && \
    # Verify metastore JAR exists
    if [ ! -f "$HIVE_HOME/lib/hive-standalone-metastore-${HIVE_VERSION}.jar" ]; then \
        echo "Error: hive-standalone-metastore-${HIVE_VERSION}.jar not found in $HIVE_HOME/lib/"; \
        echo "Contents of $HIVE_HOME/lib/:"; \
        ls -la $HIVE_HOME/lib/; \
        exit 1; \
    fi && \
    # List all JARs for verification
    echo "Contents of $HIVE_HOME/lib/:" && \
    ls -la $HIVE_HOME/lib/

# Download PostgreSQL JDBC driver
RUN curl -L https://repo1.maven.org/maven2/org/postgresql/postgresql/${POSTGRES_VERSION}/postgresql-${POSTGRES_VERSION}.jar \
    -o $HIVE_HOME/lib/postgresql-${POSTGRES_VERSION}.jar

# Switch back to root to copy files
USER root

# Copy configuration files with correct permissions
COPY --chown=hive:hive conf/hive-site.xml.template $HIVE_HOME/conf/hive-site.xml.template
COPY --chown=hive:hive conf/log4j2.xml $HIVE_HOME/conf/
COPY --chown=hive:hive conf/core-site.xml $HIVE_HOME/conf/
COPY --chown=hive:hive conf/hdfs-site.xml $HIVE_HOME/conf/

# Copy and prepare entrypoint script
COPY --chown=hive:hive scripts/entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh && \
    # Ensure script has Unix line endings
    sed -i 's/\r$//' /entrypoint.sh && \
    # Verify script is executable and has correct shebang
    head -n 1 /entrypoint.sh | grep -q '^#!/bin/bash' || (echo "Invalid shebang in entrypoint.sh" && exit 1)

# Switch back to hive user
USER hive

# Expose metastore port
EXPOSE 9083

# Add healthcheck
HEALTHCHECK CMD bash -c '</dev/tcp/localhost/9083' || exit 1

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"] 