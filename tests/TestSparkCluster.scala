package org.openbiocure.spark

import org.apache.spark.sql.{SparkSession, DataFrame}
import org.apache.spark.sql.types.{StructType, StructField, StringType, IntegerType}
import org.apache.spark.sql.functions._
import io.delta.tables._
import scala.util.{Try, Success, Failure}

object TestSparkCluster {
  // Logger setup
  private val logger = org.apache.log4j.LogManager.getLogger(this.getClass)

  def verifyDeltaJars(): Unit = {
    logger.info("=== Verifying Delta Lake JARs ===")
    val jarPath = "/opt/spark/jars"
    val deltaJars = new java.io.File(jarPath).listFiles()
      .filter(_.getName.startsWith("delta-"))
      .map(_.getName)
    
    logger.info(s"Found Delta JARs in $jarPath:")
    deltaJars.foreach(jar => logger.info(s"- $jar"))
    
    if (deltaJars.isEmpty) {
      throw new RuntimeException("No Delta Lake JARs found in /opt/spark/jars/")
    }
    
    logger.info("\nClasspath environment variables:")
    logger.info(s"SPARK_CLASSPATH: ${sys.env.getOrElse("SPARK_CLASSPATH", "Not set")}")
    logger.info(s"SPARK_HOME: ${sys.env.getOrElse("SPARK_HOME", "Not set")}")
    logger.info(s"SPARK_DAEMON_JAVA_OPTS: ${sys.env.getOrElse("SPARK_DAEMON_JAVA_OPTS", "Not set")}")
  }

  def createSparkSession(): SparkSession = {
    verifyDeltaJars()
    
    val jarPath = "/opt/spark/jars"
    val deltaJars = new java.io.File(jarPath).listFiles()
      .filter(_.getName.startsWith("delta-"))
      .map(_.getAbsolutePath)
      .mkString(",")
    
    logger.info(s"\nUsing Delta JARs: $deltaJars")
    logger.info("\nSetting up Spark session with debug logging...")
    
    SparkSession.builder()
      .appName("SparkClusterTest")
      .master(sys.env.getOrElse("SPARK_MASTER_URL", "spark://spark-arm-master:7077"))
      .config("spark.jars", deltaJars)
      .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
      .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog")
      .config("spark.driver.extraJavaOptions", "-Dlog4j.configuration=file:/opt/spark/conf/log4j2.xml -Dlog4j2.debug=true")
      .config("spark.executor.extraJavaOptions", "-Dlog4j.configuration=file:/opt/spark/conf/log4j2.xml -Dlog4j2.debug=true")
      .config("spark.driver.log.level", "DEBUG")
      .config("spark.executor.log.level", "DEBUG")
      .config("spark.sql.warehouse.dir", s"s3a://${sys.env("MINIO_BUCKET")}/warehouse")
      .config("spark.sql.catalogImplementation", "hive")
      .config("spark.hadoop.javax.jdo.option.ConnectionURL", s"jdbc:postgresql://${sys.env("POSTGRES_HOST")}:${sys.env("POSTGRES_PORT")}/${sys.env("POSTGRES_DB")}")
      .config("spark.hadoop.javax.jdo.option.ConnectionDriverName", "org.postgresql.Driver")
      .config("spark.hadoop.javax.jdo.option.ConnectionUserName", sys.env("POSTGRES_USER"))
      .config("spark.hadoop.javax.jdo.option.ConnectionPassword", sys.env("POSTGRES_PASSWORD"))
      .config("spark.hadoop.datanucleus.schema.autoCreateAll", "true")
      .config("spark.hadoop.datanucleus.autoCreateSchema", "true")
      .config("spark.hadoop.datanucleus.fixedDatastore", "false")
      .config("spark.hadoop.datanucleus.autoCreateTables", "true")
      .config("spark.delta.logStore.class", "org.apache.spark.sql.delta.storage.S3SingleDriverLogStore")
      .config("spark.delta.merge.repartitionBeforeWrite", "true")
      .config("spark.delta.autoOptimize.optimizeWrite", "true")
      .config("spark.delta.autoOptimize.autoCompact", "true")
      .config("spark.delta.storage.s3.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
      .config("spark.delta.storage.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
      .config("spark.delta.warehouse.dir", s"s3a://${sys.env("MINIO_BUCKET")}/delta")
      .config("spark.delta.optimizeWrite.enabled", "true")
      .config("spark.delta.autoCompact.enabled", "true")
      .config("spark.delta.optimizeWrite.numShuffleBlocks", "200")
      .config("spark.delta.optimizeWrite.targetFileSize", "128m")
      .config("spark.delta.concurrent.writes.enabled", "true")
      .config("spark.delta.concurrent.writes.maxConcurrentWrites", "10")
      .config("spark.delta.schema.autoMerge.enabled", "true")
      .config("spark.delta.timeTravel.enabled", "true")
      .config("spark.delta.timeTravel.retentionPeriod", "168h")
      .getOrCreate()
  }

  def testBasicSpark(spark: SparkSession): Boolean = {
    logger.info("\n=== Testing Basic Spark Functionality ===")
    
    val df = createTestDataFrame(spark)
    logger.info("Test DataFrame:")
    df.show()
    
    true
  }

  def testMinioConnectivity(spark: SparkSession): Boolean = {
    logger.info("\n=== Testing MinIO Connectivity ===")
    
    val df = createTestDataFrame(spark)
    val minioPath = s"s3a://${sys.env("MINIO_BUCKET")}/test/minio_test"
    
    logger.info(s"Writing test data to $minioPath")
    df.write
      .mode("overwrite")
      .parquet(minioPath)
    
    val readDf = spark.read.parquet(minioPath)
    logger.info("Read DataFrame from MinIO:")
    readDf.show()
    
    true
  }

  def testHiveMetastore(spark: SparkSession): Boolean = {
    logger.info("\n=== Testing Hive Metastore ===")
    
    val df = createTestDataFrame(spark)
    val tableName = "test_hive_table"
    
    logger.info(s"Creating Hive table: $tableName")
    df.write
      .mode("overwrite")
      .saveAsTable(tableName)
    
    val readDf = spark.table(tableName)
    logger.info("Read DataFrame from Hive:")
    readDf.show()
    
    true
  }

  def testDeltaLake(spark: SparkSession): Boolean = {
    logger.info("\n=== Testing Delta Lake ===")
    
    val df = createTestDataFrame(spark)
    val deltaPath = s"s3a://${sys.env("MINIO_BUCKET")}/delta/test_delta"
    
    logger.info(s"Creating Delta table at $deltaPath")
    df.write
      .format("delta")
      .mode("overwrite")
      .save(deltaPath)
    
    val readDf = spark.read
      .format("delta")
      .load(deltaPath)
    
    logger.info("Initial Delta table:")
    readDf.show()
    
    val updatesDf = createTestDataFrame(spark)
    logger.info("Updating Delta table...")
    
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
    
    logger.info("Updated Delta table:")
    updatedDf.show()
    
    true
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

  def main(args: Array[String]): Unit = {
    logger.info("Starting Spark Cluster Tests...")
    var spark: SparkSession = null
    
    try {
      spark = createSparkSession()
      
      val tests = Seq(
        ("Basic Spark", testBasicSpark _),
        ("MinIO", testMinioConnectivity _),
        ("Hive", testHiveMetastore _),
        ("Delta Lake", testDeltaLake _)
      )
      
      var allPassed = true
      for ((testName, testFunc) <- tests) {
        try {
          logger.info(s"\nRunning $testName test...")
          if (testFunc(spark)) {
            logger.info(s"✓ $testName test passed")
          } else {
            logger.error(s"✗ $testName test failed")
            allPassed = false
          }
        } catch {
          case e: Exception =>
            logger.error(s"✗ $testName test failed: ${e.getMessage}")
            allPassed = false
        }
      }
      
      logger.info("\n=== Test Summary ===")
      for ((testName, _) <- tests) {
        val status = if (allPassed) "PASSED" else "FAILED"
        logger.info(s"$testName: $status")
      }
      
      sys.exit(if (allPassed) 0 else 1)
      
    } catch {
      case e: Exception =>
        logger.error(s"Error during test execution: ${e.getMessage}")
        sys.exit(1)
    } finally {
      if (spark != null) {
        spark.stop()
      }
    }
  }
} 