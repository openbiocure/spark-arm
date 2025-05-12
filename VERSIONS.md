# Version Information

## Current Versions
- Spark: 3.5.5 (Latest stable version)
- Delta Lake: 3.0.0 (Latest version compatible with Spark 3.5.x)
- Hadoop: 3.3.6
- Scala: 2.13
- Java: 17 (OpenJDK)

## Version Selection Rationale
- Spark 3.5.5: Latest stable version with significant improvements in performance and features
- Delta Lake 3.0.0: Latest version that provides full compatibility with Spark 3.5.x
- Hadoop 3.3.6: Latest stable version with improved S3A support
- Scala 2.13: Latest stable version with better performance and features
- Java 17: LTS version with long-term support and modern features

## Dependencies
- Spark SQL & Hive: 3.5.5
- Delta Core: 3.0.0
- Hadoop AWS & Client: 3.3.6
- AWS SDK: 1.12.262
- PostgreSQL: 42.7.1
- Log4j: 2.20.0
- ScalaTest: 3.2.18

## Version Update Process
1. Check Apache Spark releases: https://spark.apache.org/downloads.html
2. Verify Delta Lake compatibility: https://docs.delta.io/latest/releases.html
3. Test all Spark operations with new versions
4. Update Dockerfile and build.sbt
5. Rebuild and test in development environment
6. Update documentation

## Migration to Pure Scala
The migration from Python to Scala was driven by:
1. Direct version control without PySpark constraints
2. Better performance without Python-Scala bridge overhead
3. Simplified dependency management through sbt
4. Immediate access to latest Spark and Delta features
5. Cleaner architecture with single language stack

## Testing
- All tests are now written in Scala
- Using ScalaTest for unit testing
- Integration tests run in Kubernetes cluster
- Test job uses spark-submit with fat JAR

## Notes
- Delta Lake 3.0.0 requires Spark >=3.5.0
- All Delta JARs in container must match version
- Test job uses spark-submit with proper classpath
- S3A filesystem configuration in spark-defaults.conf 