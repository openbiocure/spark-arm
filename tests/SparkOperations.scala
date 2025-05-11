package org.openbiocure.spark

import org.apache.spark.sql.{SparkSession, DataFrame}
import org.apache.spark.sql.types.{StructType, StructField, StringType, IntegerType}
import org.apache.spark.sql.functions._

object SparkOperations {
  // Basic Spark operations
  def createTestDataFrame(spark: SparkSession): DataFrame = {
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

  // MinIO operations
  def writeToMinIO(df: DataFrame, path: String): Unit = {
    df.write
      .mode("overwrite")
      .parquet(path)
  }

  def readFromMinIO(spark: SparkSession, path: String): DataFrame = {
    spark.read.parquet(path)
  }

  // Hive operations
  def createHiveTable(df: DataFrame, tableName: String): Unit = {
    df.write
      .mode("overwrite")
      .saveAsTable(tableName)
  }

  def readFromHive(spark: SparkSession, tableName: String): DataFrame = {
    spark.table(tableName)
  }

  // Delta Lake operations
  def createDeltaTable(df: DataFrame, path: String): Unit = {
    df.write
      .format("delta")
      .mode("overwrite")
      .save(path)
  }

  def readFromDelta(spark: SparkSession, path: String): DataFrame = {
    spark.read
      .format("delta")
      .load(path)
  }

  def updateDeltaTable(spark: SparkSession, path: String, updates: DataFrame): Unit = {
    updates.write
      .format("delta")
      .mode("overwrite")
      .save(path)
  }

  def mergeDeltaTable(spark: SparkSession, path: String, updates: DataFrame): Unit = {
    import io.delta.tables._
    
    val deltaTable = DeltaTable.forPath(spark, path)
    
    deltaTable.alias("target")
      .merge(
        updates.alias("source"),
        "target.id = source.id"
      )
      .whenMatched()
      .updateAll()
      .whenNotMatched()
      .insertAll()
      .execute()
  }
} 