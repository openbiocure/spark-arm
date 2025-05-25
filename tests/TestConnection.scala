import org.apache.spark.sql.SparkSession

object TestConnection {
  def main(args: Array[String]): Unit = {
    val spark = SparkSession.builder()
      .appName("Test Connection")
      .getOrCreate()

    println("Testing Spark connection...")
    println("Available databases:")
    spark.sql("SHOW DATABASES").show(false)
    println("Test completed successfully!")

    spark.stop()
  }
} 