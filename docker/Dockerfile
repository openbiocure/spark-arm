# Build stage for Hadoop native libraries
FROM eclipse-temurin:17-jdk-jammy AS hadoop-builder

# Set environment variables
ENV HADOOP_VERSION=3.3.6

# Install build dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Download pre-built Hadoop binary
RUN mkdir -p /opt/hadoop/lib/native && \
    curl -fSL "https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz" -o /tmp/hadoop.tar.gz && \
    tar -xf /tmp/hadoop.tar.gz -C /tmp && \
    cp -r /tmp/hadoop-${HADOOP_VERSION}/lib/native/* /opt/hadoop/lib/native/ && \
    rm -rf /tmp/hadoop.tar.gz /tmp/hadoop-${HADOOP_VERSION}

# Final stage
FROM eclipse-temurin:17-jdk-jammy

# Set environment variables
ENV SPARK_VERSION=3.5.5
ENV HADOOP_VERSION=3.3.6
ENV DELTA_VERSION=3.3.1
ENV SPARK_HOME=/opt/spark
ENV PATH=$PATH:$SPARK_HOME/bin
ENV HADOOP_HOME=/opt/hadoop
ENV LD_LIBRARY_PATH=/opt/hadoop/lib/native
ENV SPARK_CLASSPATH=/opt/spark/jars/*

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    netcat-openbsd \
    procps \
    tini \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Set Python environment variables
ENV PYTHONPATH=/opt/spark/python:/opt/spark/python/lib/py4j-0.10.9.7-src.zip
ENV PYSPARK_PYTHON=python3
ENV PYSPARK_DRIVER_PYTHON=python3

# Install Python dependencies
RUN pip3 install --no-cache-dir \
    pyspark==${SPARK_VERSION} \
    delta-spark==${DELTA_VERSION} \
    pyarrow \
    pandas \
    numpy

# Create necessary directories
RUN mkdir -p ${SPARK_HOME} ${HADOOP_HOME}/lib/native ${SPARK_HOME}/jars

# Copy Hadoop native libraries from builder stage
COPY --from=hadoop-builder /opt/hadoop/lib/native ${HADOOP_HOME}/lib/native/

# Download and install Spark
RUN curl -fSL "https://dlcdn.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3-scala2.13.tgz" -o /tmp/spark.tgz && \
    tar -xf /tmp/spark.tgz -C /opt && \
    mv /opt/spark-${SPARK_VERSION}-bin-hadoop3-scala2.13/* ${SPARK_HOME} && \
    rm -rf /tmp/spark.tgz /opt/spark-${SPARK_VERSION}-bin-hadoop3-scala2.13

# Download Delta Lake and S3A dependencies
RUN for jar in \
    "delta-core_2.13/${DELTA_VERSION}/delta-core_2.13-${DELTA_VERSION}.jar" \
    "delta-storage/${DELTA_VERSION}/delta-storage-${DELTA_VERSION}.jar" \
    "delta-hive_2.13/${DELTA_VERSION}/delta-hive_2.13-${DELTA_VERSION}.jar" \
    "delta-standalone_2.13/${DELTA_VERSION}/delta-standalone_2.13-${DELTA_VERSION}.jar" \
    "delta-contribs_2.13/${DELTA_VERSION}/delta-contribs_2.13-${DELTA_VERSION}.jar" \
    "hadoop-aws/${HADOOP_VERSION}/hadoop-aws-${HADOOP_VERSION}.jar" \
    "aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar"; do \
    echo "Downloading $jar" && \
    curl -fSL "https://repo1.maven.org/maven2/io/delta/${jar}" -o "${SPARK_HOME}/jars/$(basename $jar)" || \
    curl -fSL "https://repo1.maven.org/maven2/org/apache/hadoop/${jar}" -o "${SPARK_HOME}/jars/$(basename $jar)" || \
    curl -fSL "https://repo1.maven.org/maven2/com/amazonaws/${jar}" -o "${SPARK_HOME}/jars/$(basename $jar)" || \
    (echo "Failed to download $jar" && exit 1); \
done

# Create spark-defaults.conf with necessary configurations
RUN echo "spark.driver.extraClassPath /opt/spark/jars/*" > ${SPARK_HOME}/conf/spark-defaults.conf && \
    echo "spark.executor.extraClassPath /opt/spark/jars/*" >> ${SPARK_HOME}/conf/spark-defaults.conf && \
    echo "spark.sql.extensions io.delta.sql.DeltaSparkSessionExtension" >> ${SPARK_HOME}/conf/spark-defaults.conf && \
    echo "spark.sql.catalog.spark_catalog org.apache.spark.sql.delta.catalog.DeltaCatalog" >> ${SPARK_HOME}/conf/spark-defaults.conf

# Copy scripts
COPY docker/scripts/ ${SPARK_HOME}/scripts/
RUN chmod +x ${SPARK_HOME}/scripts/*.sh

# Set working directory
WORKDIR ${SPARK_HOME}

# Use tini as init process
ENTRYPOINT ["/usr/bin/tini", "--"]

# Default command
CMD ["/opt/spark/scripts/start-spark.sh"] 