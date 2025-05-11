name := "spark-arm"
version := "0.1.0"
scalaVersion := "2.13.12"

// Spark dependencies
val sparkVersion = "3.4.2"
val deltaVersion = "2.4.0"

libraryDependencies ++= Seq(
  // Spark Core
  "org.apache.spark" %% "spark-sql" % sparkVersion,
  "org.apache.spark" %% "spark-hive" % sparkVersion,
  
  // Delta Lake
  "io.delta" %% "delta-core" % deltaVersion,
  "io.delta" %% "delta-storage" % deltaVersion,
  
  // Testing
  "org.scalatest" %% "scalatest" % "3.2.17" % Test,
  "org.scalamock" %% "scalamock" % "5.2.0" % Test,
  
  // Logging
  "ch.qos.logback" % "logback-classic" % "1.4.14",
  "com.typesafe.scala-logging" %% "scala-logging" % "3.9.5"
)

// Assembly plugin for creating fat JARs
assembly / assemblyMergeStrategy := {
  case PathList("META-INF", xs @ _*) => MergeStrategy.discard
  case x => MergeStrategy.first
}

// Compiler options
scalacOptions ++= Seq(
  "-deprecation",
  "-feature",
  "-unchecked",
  "-Xlint",
  "-Ywarn-dead-code",
  "-Ywarn-numeric-widen",
  "-Ywarn-value-discard"
)

// Test options
Test / parallelExecution := false
Test / logBuffered := false 