package org.openbiocure.spark

import org.apache.spark.sql.{SparkSession, DataFrame}
import org.apache.spark.sql.types.{StructType, StructField, StringType, IntegerType}
import org.apache.spark.sql.functions._
import io.delta.tables._
import scala.util.{Try, Success, Failure}
import org.apache.spark.internal.Logging

object TestSparkCluster extends Logging {
  private var spark: SparkSession = _

  def main(args: Array[String]): Unit = {
    logInfo("Starting Spark Cluster Tests...")
    
    try {
      spark = createSparkSession()
      
      val tests = Seq(
        ("Basic Spark", () => testBasicSpark(spark)),
        ("MinIO", () => testMinioConnectivity(spark)),
        ("Hive", () => testHiveMetastore(spark)),
        ("Delta Lake", () => testDeltaLake(spark))
      )
      
      var allPassed = true
      for ((testName, testFunc) <- tests) {
        try {
          logInfo(s"\nRunning $testName test...")
          if (testFunc()) {
            logInfo(s"✓ $testName test passed")
          } else {
            logError(s"✗ $testName test failed")
            allPassed = false
          }
        } catch {
          case e: Exception =>
            logError(s"✗ $testName test failed: ${e.getMessage}")
            allPassed = false
        }
      }
      
      logInfo("\n=== Test Summary ===")
      for ((testName, _) <- tests) {
        val status = if (allPassed) "PASSED" else "FAILED"
        logInfo(s"$testName: $status")
      }
      
      sys.exit(if (allPassed) 0 else 1)
      
    } catch {
      case e: Exception =>
        logError(s"Error during test execution: ${e.getMessage}")
        sys.exit(1)
    } finally {
      if (spark != null) {
        spark.stop()
      }
    }
  }

  def verifyDeltaJars(): Unit = {
    logInfo("=== Verifying Delta Lake JARs ===")
    
    // For local development, skip jar verification
    if (sys.env.getOrElse("SPARK_MASTER_URL", "").startsWith("local")) {
      logInfo("Running in local mode, skipping Delta JAR verification")
      return
    }
    
    // Only verify jars in cluster mode
    val jarPath = "/opt/spark/jars"
    if (!new java.io.File(jarPath).exists()) {
      logInfo(s"Jar path $jarPath does not exist, skipping verification")
      return
    }
    
    try {
      val deltaJars = new java.io.File(jarPath).listFiles()
        .filter(_.getName.startsWith("delta-"))
        .map(_.getName)
      
      logInfo(s"Found Delta JARs in $jarPath:")
      deltaJars.foreach(jar => logInfo(s"- $jar"))
      
      if (deltaJars.isEmpty) {
        throw new RuntimeException("No Delta Lake JARs found in /opt/spark/jars/")
      }
    } catch {
      case e: Exception =>
        logError(s"Error verifying Delta JARs: ${e.getMessage}")
        throw e
    }
    
    logInfo("\nClasspath environment variables:")
    logInfo(s"SPARK_CLASSPATH: ${sys.env.getOrElse("SPARK_CLASSPATH", "Not set")}")
    logInfo(s"SPARK_HOME: ${sys.env.getOrElse("SPARK_HOME", "Not set")}")
    logInfo(s"SPARK_DAEMON_JAVA_OPTS: ${sys.env.getOrElse("SPARK_DAEMON_JAVA_OPTS", "Not set")}")
  }

  def initializeHiveMetastore(): Unit = {
    logInfo("\n=== Initializing Hive Metastore Schema ===")
    
    try {
      logInfo("Initializing Hive metastore schema...")
      // Run schematool to initialize the schema
      val schematoolCmd = Array(
        "/opt/spark/bin/schematool",
        "-dbType", "postgres",
        "-initSchema",
        "-verbose"
      )
      
      val schematoolProcess = Runtime.getRuntime.exec(schematoolCmd)
      val schematoolOutput = scala.io.Source.fromInputStream(schematoolProcess.getInputStream).mkString
      val schematoolError = scala.io.Source.fromInputStream(schematoolProcess.getErrorStream).mkString
      val schematoolExitCode = schematoolProcess.waitFor()
      
      if (schematoolExitCode == 0) {
        logInfo("Successfully initialized Hive metastore schema")
        logInfo(schematoolOutput)
      } else {
        logError(s"Failed to initialize Hive metastore schema: $schematoolError")
        throw new RuntimeException("Failed to initialize Hive metastore schema")
      }
    } catch {
      case e: Exception =>
        logError(s"Error initializing Hive metastore: ${e.getMessage}")
        throw e
    }
  }

  def createSparkSession(): SparkSession = {
    verifyDeltaJars()
    
    val isLocalMode = sys.env.getOrElse("SPARK_MASTER_URL", "").startsWith("local")
    logInfo(s"\nRunning in ${if (isLocalMode) "local" else "cluster"} mode")
    
    if (!isLocalMode) {
      initializeHiveMetastore()
      createMinioBucket()
    }
    
    logInfo("\nSetting up Spark session with debug logging...")
    
    val builder = SparkSession.builder()
      .appName("SparkClusterTest")
      .master(sys.env.getOrElse("SPARK_MASTER_URL", "local[*]"))
      .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
      .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog")
      .config("spark.driver.log.level", "DEBUG")
      .config("spark.executor.log.level", "DEBUG")
      // Always include MinIO and PostgreSQL configs
      .config("spark.hadoop.fs.s3a.endpoint", sys.env("AWS_ENDPOINT_URL"))
      .config("spark.hadoop.fs.s3a.access.key", sys.env("AWS_ACCESS_KEY_ID"))
      .config("spark.hadoop.fs.s3a.secret.key", sys.env("AWS_SECRET_ACCESS_KEY"))
      .config("spark.hadoop.fs.s3a.path.style.access", "true")
      .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
      .config("spark.hadoop.fs.s3a.aws.credentials.provider", "org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider")
      .config("spark.sql.warehouse.dir", s"s3a://${sys.env("MINIO_BUCKET")}/warehouse")
      .config("spark.sql.catalogImplementation", "hive")
      .config("spark.hadoop.javax.jdo.option.ConnectionURL", s"jdbc:postgresql://${sys.env("POSTGRES_HOST")}:${sys.env("POSTGRES_PORT")}/${sys.env("POSTGRES_DB")}")
      .config("spark.hadoop.javax.jdo.option.ConnectionDriverName", "org.postgresql.Driver")
      .config("spark.hadoop.javax.jdo.option.ConnectionUserName", sys.env("POSTGRES_USER"))
      .config("spark.hadoop.javax.jdo.option.ConnectionPassword", sys.env("POSTGRES_PASSWORD"))
    
    if (isLocalMode) {
      builder
        .config("spark.driver.extraJavaOptions", "-Djava.security.manager=disallow")
        .config("spark.executor.extraJavaOptions", "-Djava.security.manager=disallow")
        .config("spark.local.ip", "127.0.0.1")
        .config("spark.driver.host", "127.0.0.1")
        .config("spark.driver.bindAddress", "127.0.0.1")
    }
    
    builder.getOrCreate()
  }

  def testBasicSpark(spark: SparkSession): Boolean = {
    logInfo("\n=== Testing Basic Spark Functionality ===")
    try {
      val df = createTestDataFrame(spark)
      logInfo("Test DataFrame:")
      df.show()
      true
    } catch {
      case e: Exception =>
        logError(s"Basic Spark test failed: ${e.getMessage}")
        logError(s"Stack trace: ${e.getStackTrace.mkString("\n")}")
        false
    }
  }

  def testMinioConnectivity(spark: SparkSession): Boolean = {
    logInfo("\n=== Testing MinIO Connectivity ===")
    try {
      val df = createTestDataFrame(spark)
      val minioPath = s"s3a://${sys.env("MINIO_BUCKET")}/test/minio_test"
      
      logInfo(s"Writing test data to $minioPath")
      df.write
        .mode("overwrite")
        .parquet(minioPath)
      
      val readDf = spark.read.parquet(minioPath)
      logInfo("Read DataFrame from MinIO:")
      readDf.show()
      true
    } catch {
      case e: Exception =>
        logError(s"MinIO test failed: ${e.getMessage}")
        logError(s"Stack trace: ${e.getStackTrace.mkString("\n")}")
        false
    }
  }

  def testHiveMetastore(spark: SparkSession): Boolean = {
    logInfo("\n=== Testing Hive Metastore ===")
    try {
      val df = createTestDataFrame(spark)
      val tableName = "test_hive_table"
      
      logInfo(s"Creating Hive table: $tableName")
      df.write
        .mode("overwrite")
        .saveAsTable(tableName)
      
      val readDf = spark.table(tableName)
      logInfo("Read DataFrame from Hive:")
      readDf.show()
      true
    } catch {
      case e: Exception =>
        logError(s"Hive test failed: ${e.getMessage}")
        logError(s"Stack trace: ${e.getStackTrace.mkString("\n")}")
        false
    }
  }

  def testDeltaLake(spark: SparkSession): Boolean = {
    logInfo("\n=== Testing Delta Lake ===")
    try {
      val df = createTestDataFrame(spark)
      val deltaPath = s"s3a://${sys.env("MINIO_BUCKET")}/delta/test_delta"
      
      logInfo(s"Creating Delta table at $deltaPath")
      df.write
        .format("delta")
        .mode("overwrite")
        .save(deltaPath)
      
      val readDf = spark.read
        .format("delta")
        .load(deltaPath)
      
      logInfo("Initial Delta table:")
      readDf.show()
      
      val updatesDf = createTestDataFrame(spark)
      logInfo("Updating Delta table...")
      
      val deltaTable = DeltaTable.forPath(spark, deltaPath)
      deltaTable.alias("target")
        .merge(
          updatesDf.alias("source"),
          "target.id = source.id"
        )
        .whenMatched()
        .updateAll()
        .whenNotMatched()
        .insertAll()
        .execute()
      
      val updatedDf = spark.read
        .format("delta")
        .load(deltaPath)
      
      logInfo("Updated Delta table:")
      updatedDf.show()
      true
    } catch {
      case e: Exception =>
        logError(s"Delta Lake test failed: ${e.getMessage}")
        logError(s"Stack trace: ${e.getStackTrace.mkString("\n")}")
        false
    }
  }

  private def createTestDataFrame(spark: SparkSession): DataFrame = {
    val schema = StructType(Seq(
      StructField("id", IntegerType, nullable = false),
      StructField("name", StringType, nullable = false)
    ))
    
    val data = Seq(
      (1, "test1"),
      (2, "test2"),
      (3, "test3")
    )
    
    spark.createDataFrame(data).toDF("id", "name")
  }

  private def createMinioBucket(): Unit = {
    logInfo("\n=== Creating MinIO Bucket if it doesn't exist ===")
    val bucket = sys.env("MINIO_BUCKET")
    
    try {
      // Create a temporary script to create the bucket
      val script = s"""
        |#!/bin/bash
        |mc alias set myminio ${sys.env("AWS_ENDPOINT_URL")} ${sys.env("AWS_ACCESS_KEY_ID")} ${sys.env("AWS_SECRET_ACCESS_KEY")}
        |mc mb myminio/$bucket --ignore-existing
        |mc ls myminio/$bucket
        |""".stripMargin
      
      val scriptFile = new java.io.File("/tmp/create_bucket.sh")
      val writer = new java.io.FileWriter(scriptFile)
      writer.write(script)
      writer.close()
      scriptFile.setExecutable(true)
      
      // Execute the script
      val process = Runtime.getRuntime.exec(Array("/bin/bash", scriptFile.getAbsolutePath))
      val exitCode = process.waitFor()
      
      if (exitCode == 0) {
        logInfo(s"Successfully created/verified bucket: $bucket")
      } else {
        val error = scala.io.Source.fromInputStream(process.getErrorStream).mkString
        logError(s"Failed to create bucket: $error")
        throw new RuntimeException(s"Failed to create MinIO bucket: $bucket")
      }
    } catch {
      case e: Exception =>
        logError(s"Error creating MinIO bucket: ${e.getMessage}")
        throw e
    }
  }
} 