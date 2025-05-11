name := "spark-arm-tests"
version := "1.0.0"
scalaVersion := "2.13.12"

libraryDependencies ++= Seq(
  "org.apache.spark" %% "spark-sql" % "3.5.3",
  "org.apache.spark" %% "spark-hive" % "3.5.3",
  "io.delta" %% "delta-core" % "3.0.0",
  "org.apache.hadoop" % "hadoop-aws" % "3.3.6",
  "org.apache.hadoop" % "hadoop-client" % "3.3.6",
  "org.postgresql" % "postgresql" % "42.7.1",
  "org.apache.logging.log4j" % "log4j-api" % "2.20.0",
  "org.apache.logging.log4j" % "log4j-core" % "2.20.0",
  "org.apache.logging.log4j" % "log4j-slf4j-impl" % "2.20.0",
  "org.scalatest" %% "scalatest" % "3.2.18" % Test
)

// Assembly plugin settings for creating fat JAR
assembly / assemblyMergeStrategy := {
  case PathList("META-INF", xs @ _*) => MergeStrategy.discard
  case x => MergeStrategy.first
}

// Exclude Scala library from assembly
assembly / assemblyOption := (assembly / assemblyOption).value.copy(includeScala = false)

// Add assembly plugin
enablePlugins(AssemblyPlugin) 