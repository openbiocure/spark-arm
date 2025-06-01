# syntax=docker/dockerfile:1.4

# Define build arguments for versions
ARG SPARK_VERSION
ARG HADOOP_VERSION
ARG DELTA_VERSION
ARG AWS_SDK_VERSION
ARG SCALA_VERSION
ARG SPARK_URL_TEMPLATE
ARG HADOOP_URL_TEMPLATE
ARG DELTA_CORE_URL_TEMPLATE
ARG DELTA_SPARK_URL_TEMPLATE
ARG AWS_BUNDLE_URL_TEMPLATE
ARG AWS_S3_URL_TEMPLATE
ARG HADOOP_AWS_URL_TEMPLATE

# Stage 1: URL verification (lightweight)
FROM eclipse-temurin:17-jdk-jammy AS url-verifier
# Create scripts directory
RUN mkdir -p /opt/spark/scripts

# Copy only the scripts needed for verification
COPY docker/scripts/logging.sh /opt/spark/scripts/
COPY docker/scripts/verify-urls.sh docker/scripts/install-verifier-deps.sh /tmp/
COPY versions.sh /opt/spark/scripts/
RUN chmod +x /tmp/*.sh /opt/spark/scripts/*.sh

# Set version environment variables for verification
ARG SPARK_VERSION
ARG HADOOP_VERSION
ARG DELTA_VERSION
ARG AWS_SDK_VERSION
ARG SCALA_VERSION
ARG SPARK_URL_TEMPLATE
ARG HADOOP_URL_TEMPLATE
ARG DELTA_CORE_URL_TEMPLATE
ARG DELTA_SPARK_URL_TEMPLATE
ARG AWS_BUNDLE_URL_TEMPLATE
ARG AWS_S3_URL_TEMPLATE
ARG HADOOP_AWS_URL_TEMPLATE

# Export all variables to environment
ENV SPARK_VERSION="${SPARK_VERSION}" \
    HADOOP_VERSION="${HADOOP_VERSION}" \
    DELTA_VERSION="${DELTA_VERSION}" \
    AWS_SDK_VERSION="${AWS_SDK_VERSION}" \
    SCALA_VERSION="${SCALA_VERSION}" \
    SPARK_URL_TEMPLATE="${SPARK_URL_TEMPLATE}" \
    HADOOP_URL_TEMPLATE="${HADOOP_URL_TEMPLATE}" \
    DELTA_CORE_URL_TEMPLATE="${DELTA_CORE_URL_TEMPLATE}" \
    DELTA_SPARK_URL_TEMPLATE="${DELTA_SPARK_URL_TEMPLATE}" \
    AWS_BUNDLE_URL_TEMPLATE="${AWS_BUNDLE_URL_TEMPLATE}" \
    AWS_S3_URL_TEMPLATE="${AWS_S3_URL_TEMPLATE}" \
    HADOOP_AWS_URL_TEMPLATE="${HADOOP_AWS_URL_TEMPLATE}"

# Debug output for environment variables
RUN echo "Debug: Environment variables in url-verifier stage:"

# Install URL verification dependencies and run verification
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    /tmp/install-verifier-deps.sh && \
    /tmp/verify-urls.sh && \
    touch /tmp/urls-verified

# Stage 2: Final runtime image
FROM --platform=linux/arm64 eclipse-temurin:17-jdk-jammy

# Common environment variables
ENV SPARK_HOME=/opt/spark \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/spark/bin \
    HADOOP_HOME=/opt/hadoop \
    LD_LIBRARY_PATH=/opt/hadoop/lib/native \
    SPARK_CLASSPATH=/opt/spark/jars/* \
    HADOOP_OPTS="-Djava.library.path=/opt/hadoop/lib/native"

# Copy verification marker
COPY --from=url-verifier /tmp/urls-verified /tmp/

# Copy all scripts
COPY docker/scripts/ ${SPARK_HOME}/scripts/
COPY versions.sh ${SPARK_HOME}/scripts/
RUN chmod +x ${SPARK_HOME}/scripts/*.sh

# Set version environment variables
ARG SPARK_VERSION
ARG HADOOP_VERSION
ARG DELTA_VERSION
ARG AWS_SDK_VERSION
ARG SCALA_VERSION
ARG SPARK_URL_TEMPLATE
ARG HADOOP_URL_TEMPLATE
ARG DELTA_CORE_URL_TEMPLATE
ARG DELTA_SPARK_URL_TEMPLATE
ARG AWS_BUNDLE_URL_TEMPLATE
ARG AWS_S3_URL_TEMPLATE
ARG HADOOP_AWS_URL_TEMPLATE

ENV SPARK_VERSION=${SPARK_VERSION} \
    HADOOP_VERSION=${HADOOP_VERSION} \
    DELTA_VERSION=${DELTA_VERSION} \
    AWS_SDK_VERSION=${AWS_SDK_VERSION} \
    SCALA_VERSION=${SCALA_VERSION} \
    SPARK_SCALA_VERSION=${SCALA_VERSION} \
    SPARK_URL_TEMPLATE=${SPARK_URL_TEMPLATE} \
    HADOOP_URL_TEMPLATE=${HADOOP_URL_TEMPLATE} \
    DELTA_CORE_URL_TEMPLATE=${DELTA_CORE_URL_TEMPLATE} \
    DELTA_SPARK_URL_TEMPLATE=${DELTA_SPARK_URL_TEMPLATE} \
    AWS_BUNDLE_URL_TEMPLATE=${AWS_BUNDLE_URL_TEMPLATE} \
    AWS_S3_URL_TEMPLATE=${AWS_S3_URL_TEMPLATE} \
    HADOOP_AWS_URL_TEMPLATE=${HADOOP_AWS_URL_TEMPLATE}

# Install system dependencies and create user
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        netcat-openbsd \
        procps \
        tini \
        coreutils \
        bash \
        net-tools \
        iproute2 \
        dnsutils \
        htop \
        vim-tiny \
        less \
        file \
        make \
        cmake \
        gcc \
        g++ \
        libssl-dev \
        zlib1g-dev \
        && rm -rf /var/lib/apt/lists/* && \
    # Create necessary directories
    mkdir -p ${SPARK_HOME}/logs/events && \
    mkdir -p ${SPARK_HOME}/tmp && \
    mkdir -p ${SPARK_HOME}/work && \
    mkdir -p ${HADOOP_HOME}/lib/native && \
    # Run the user setup script
    ${SPARK_HOME}/scripts/setup-user.sh && \
    # Set permissions for directories
    chown -R spark:spark ${SPARK_HOME}/logs ${SPARK_HOME}/tmp ${SPARK_HOME}/work ${HADOOP_HOME}

# Install Hadoop native libraries as root
RUN --mount=type=cache,target=/tmp/downloads \
    ${SPARK_HOME}/scripts/install-hadoop-native.sh ${HADOOP_VERSION} ${HADOOP_HOME}

# Download and install Spark as spark user
USER spark
RUN --mount=type=cache,target=/tmp/downloads \
    ${SPARK_HOME}/scripts/download-spark.sh ${SPARK_HOME}

# Copy and set up log4j2.xml as root
USER root
COPY docker/conf/log4j2.xml ${SPARK_HOME}/conf/
RUN chown spark:spark ${SPARK_HOME}/conf/log4j2.xml && \
    chmod 644 ${SPARK_HOME}/conf/log4j2.xml

# Switch back to spark user for remaining operations
USER spark

# Download all required JARs in parallel as spark user
RUN --mount=type=cache,target=/tmp/downloads \
    ${SPARK_HOME}/scripts/download-jars.sh

# Create spark-defaults.conf as spark user
RUN ${SPARK_HOME}/scripts/create-spark-defaults.sh

# Set working directory
WORKDIR ${SPARK_HOME}

# Use tini as init process
ENTRYPOINT ["/usr/bin/tini", "--"]

# Default command (will run as spark user)
CMD ["/opt/spark/scripts/start-spark.sh"] 