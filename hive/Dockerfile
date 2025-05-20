# syntax=docker/dockerfile:1.4

# Use the same base image as Spark for consistency
FROM eclipse-temurin:17-jdk-jammy

# Define build arguments
ARG HADOOP_VERSION
ARG HIVE_VERSION
ARG POSTGRES_VERSION
ARG POSTGRES_URL_TEMPLATE

# Set environment variables
ENV HADOOP_HOME=/opt/hadoop \
    HIVE_HOME=/opt/hive \
    PATH=/opt/hadoop/bin:/opt/hive/bin:$PATH \
    SERVICE_NAME=metastore \
    DB_DRIVER=postgres \
    SERVICE_OPTS="-Djavax.jdo.option.ConnectionDriverName=org.postgresql.Driver \
                  -Djavax.jdo.option.ConnectionURL=jdbc:postgresql://${HIVE_METASTORE_DB_HOST:-postgresql}:${HIVE_METASTORE_DB_PORT:-5432}/${HIVE_METASTORE_DB_NAME:-hive} \
                  -Djavax.jdo.option.ConnectionUserName=${HIVE_METASTORE_DB_USER:-hive} \
                  -Djavax.jdo.option.ConnectionPassword=${HIVE_METASTORE_DB_PASSWORD:-hive}"

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    procps \
    postgresql-client \
    net-tools \
    netcat-openbsd \
    openjdk-17-jdk \
    libpostgresql-jdbc-java \
    gettext \
    lsof \
    coreutils \
    grep \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories and set permissions
RUN mkdir -p ${HADOOP_HOME} ${HIVE_HOME}/logs ${HIVE_HOME}/conf ${HIVE_HOME}/warehouse ${HIVE_HOME}/scratch \
    && groupadd -r hive && useradd -r -g hive hive \
    && chown -R hive:hive ${HADOOP_HOME} ${HIVE_HOME} \
    && chmod 755 ${HADOOP_HOME} ${HIVE_HOME} \
    && chmod 777 ${HIVE_HOME}/logs ${HIVE_HOME}/warehouse ${HIVE_HOME}/scratch \
    && chmod 777 /tmp \
    && chmod -R 775 ${HIVE_HOME}/conf \
    && chown -R hive:hive ${HIVE_HOME}/conf \
    && touch ${HIVE_HOME}/warehouse/.testfile && rm ${HIVE_HOME}/warehouse/.testfile \
    && echo "Directory permissions verified" \
    && ls -la ${HIVE_HOME}

# Copy installation scripts
COPY scripts/logging.sh scripts/install-hadoop.sh scripts/install-hive.sh /tmp/
RUN chmod +x /tmp/*.sh

# Install Hadoop and Hive
RUN . /tmp/logging.sh && init_logging && \
    /tmp/install-hadoop.sh ${HADOOP_VERSION} ${HADOOP_HOME} && \
    rm -rf ${HIVE_HOME}/lib && \
    /tmp/install-hive.sh ${HIVE_VERSION} ${HIVE_HOME}

# Create symlink for PostgreSQL JDBC driver after Hive installation and ensure correct ownership
RUN ln -sf /usr/share/java/postgresql-jdbc4.jar ${HIVE_HOME}/lib/postgresql.jar \
    && chown -h hive:hive ${HIVE_HOME}/lib/postgresql.jar \
    && chmod 644 ${HIVE_HOME}/lib/postgresql.jar

# Copy configuration files
COPY conf/hive-site.xml.template ${HIVE_HOME}/conf/
COPY conf/hive-log4j2.properties.template ${HIVE_HOME}/conf/hive-log4j2.properties
COPY conf/core-site.xml ${HADOOP_HOME}/etc/hadoop/
COPY conf/hdfs-site.xml ${HADOOP_HOME}/etc/hadoop/
RUN chown -R hive:hive ${HIVE_HOME}/conf ${HADOOP_HOME}/etc/hadoop \
    && chmod -R 775 ${HIVE_HOME}/conf ${HADOOP_HOME}/etc/hadoop \
    && chmod 644 ${HIVE_HOME}/conf/hive-log4j2.properties \
    && echo "Log4j2 configuration copied and permissions set"

# Create hive-env.sh with driver configuration
RUN echo "export HIVE_AUX_JARS_PATH=${HIVE_HOME}/lib/postgresql.jar" > ${HIVE_HOME}/conf/hive-env.sh && \
    echo "export HADOOP_CLASSPATH=${HIVE_HOME}/lib/postgresql.jar:\${HADOOP_CLASSPATH:-}" >> ${HIVE_HOME}/conf/hive-env.sh && \
    chown hive:hive ${HIVE_HOME}/conf/hive-env.sh

# Copy startup scripts and logging
COPY scripts/start-hive.sh scripts/logging.sh ${HIVE_HOME}/bin/
RUN chmod +x ${HIVE_HOME}/bin/*.sh \
    && chown hive:hive ${HIVE_HOME}/bin/*.sh

# Set working directory and ensure it's writable
WORKDIR ${HIVE_HOME}
RUN chown hive:hive ${HIVE_HOME} && chmod 755 ${HIVE_HOME}

# Use hive user
USER hive

# Default command
CMD ["/opt/hive/bin/start-hive.sh"] 