#!/usr/bin/env python3
"""Download required JAR files for Spark."""

import os
import sys
import logging
import requests
from pathlib import Path
from typing import Dict, Any

# Add the scripts directory to Python path
scripts_dir = Path(__file__).parent
sys.path.append(str(scripts_dir))

try:
    from env import SparkEnv
except ImportError:
    raise ImportError("Could not import SparkEnv from env.py")

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(levelname)s] %(asctime)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

def download_file(url: str, dest: Path) -> None:
    """Download a file from URL to destination."""
    logger.info(f"Downloading {url} to {dest}")
    response = requests.get(url, stream=True)
    response.raise_for_status()
    
    with open(dest, 'wb') as f:
        for chunk in response.iter_content(chunk_size=8192):
            f.write(chunk)

def main() -> None:
    """Download required JAR files."""
    try:
        # Load environment configuration
        env = SparkEnv.load()
        
        # Create download directory
        download_dir = Path('/tmp/downloads')
        download_dir.mkdir(parents=True, exist_ok=True)
        
        # Download Spark (with Hadoop included)
        spark_url = f"https://archive.apache.org/dist/spark/spark-{env.spark_version}/spark-{env.spark_version}-bin-hadoop3.tgz"
        spark_dest = download_dir / "spark.tgz"
        download_file(spark_url, spark_dest)
        
        # Download Delta Lake
        delta_url = f"https://repo1.maven.org/maven2/io/delta/delta-spark_{env.scala_version}/3.3.2/delta-spark_{env.scala_version}-3.3.2.jar"
        delta_dest = download_dir / "delta-spark.jar"
        download_file(delta_url, delta_dest)
        
        # Download Hadoop AWS
        hadoop_aws_url = "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.2/hadoop-aws-3.3.2.jar"
        hadoop_aws_dest = download_dir / "hadoop-aws.jar"
        download_file(hadoop_aws_url, hadoop_aws_dest)
        
        # Download AWS SDK Bundle
        aws_sdk_url = "https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.11.1026/aws-java-sdk-bundle-1.11.1026.jar"
        aws_sdk_dest = download_dir / "aws-java-sdk-bundle.jar"
        download_file(aws_sdk_url, aws_sdk_dest)
        
        logger.info("Download complete")
        
    except Exception as e:
        logger.error(f"Failed to download files: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 