# Fix Hadoop Version Mismatch Issue

## Current Problem
- Spark 3.5.5's pre-built binary (spark-3.5.5-bin-hadoop3-scala2.13.tgz) includes:
  - hadoop-client-api-3.3.4.jar
  - hadoop-client-runtime-3.3.4.jar
  - hadoop-yarn-server-web-proxy-3.3.4.jar
  - hadoop-shaded-guava-1.1.1.jar
  - parquet-hadoop-1.13.1.jar
  - And other Hadoop 3.3.4 related JARs
  - These are the core Hadoop libraries that Spark uses for its filesystem operations
- We're using hadoop-aws-3.3.6.jar which expects Hadoop 3.3.6
- This causes ClassNotFoundException for org.apache.hadoop.fs.impl.prefetch.PrefetchingStatistics
  because this class exists in Hadoop 3.3.6 but not in the 3.3.4 libraries that Spark provides

## How the Mismatch Happens
1. In versions.sh (get_versions function):
   ```bash
   local SPARK_VERSION="3.5.5"
   local HADOOP_VERSION="3.3.6"
   ```
   - These local variables are used to construct URLs
   - HADOOP_VERSION is used to build HADOOP_AWS_URL_TEMPLATE for hadoop-aws-3.3.6.jar
   - The function exports these as environment variables for other scripts to use

2. In docker/scripts/download-spark.sh:
   - Downloads spark-3.5.5-bin-hadoop3-scala2.13.tgz
   - This pre-built binary contains Hadoop 3.3.4 libraries
   - These become the core Hadoop libraries used by Spark

3. In docker/scripts/download-jars.sh:
   - Downloads additional JARs including hadoop-aws-3.3.6.jar
   - This JAR expects Hadoop 3.3.6 classes
   - But Spark is running with Hadoop 3.3.4 libraries

## Required Changes

1. In versions.sh:
   - Change HADOOP_VERSION from "3.3.6" to "3.3.4" to match Spark's built-in version
   - Update HADOOP_AWS_URL_TEMPLATE to use 3.3.4 instead of 3.3.6

2. In docker/Dockerfile:
   - No changes needed as it uses versions from versions.sh
   - Will automatically pick up the new Hadoop version

3. After Changes:
   - Rebuild Spark Docker image to ensure new versions are used
   - Test S3 connectivity to verify the fix
   - Verify no ClassNotFoundException errors occur

## Future Consideration
- Plan a separate upgrade to Spark 4.0.0 as a future project
- This will allow proper testing and validation of all Spark 4.0.0 features
- Keep current fix focused on resolving the immediate Hadoop version mismatch