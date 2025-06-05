#!/usr/bin/env python3
"""Download and install Spark components."""

import os
import sys
import logging
import subprocess
from pathlib import Path
from typing import List, Optional
from dataclasses import dataclass

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

@dataclass
class Component:
    """Component to download."""
    name: str
    version: str
    url: str
    target_dir: str
    filename: str

def get_components(env: SparkEnv) -> List[Component]:
    """Get list of components to download."""
    spark_home = env.spark_home
    scala_version = "2.12"  # TODO: Make this configurable in env.py
    
    return [
        # Apache Spark (without Hadoop)
        Component(
            name="Apache Spark",
            version="3.5.3",  # TODO: Make this configurable in env.py
            url=f"https://archive.apache.org/dist/spark/spark-3.5.3/spark-3.5.3-bin-without-hadoop.tgz",
            target_dir="/tmp/downloads",
            filename="spark.tgz"
        ),
        # Apache Hadoop
        Component(
            name="Apache Hadoop",
            version="3.3.2",  # TODO: Make this configurable in env.py
            url=f"https://archive.apache.org/dist/hadoop/common/hadoop-3.3.2/hadoop-3.3.2.tar.gz",
            target_dir="/tmp/downloads",
            filename="hadoop.tgz"
        ),
        # Delta Lake Components
        Component(
            name="Delta Lake Core",
            version="3.0.0",  # TODO: Make this configurable in env.py
            url=f"https://repo1.maven.org/maven2/io/delta/delta-core_{scala_version}/3.0.0/delta-core_{scala_version}-3.0.0.jar",
            target_dir=f"{spark_home}/jars/delta",
            filename="delta-core.jar"
        ),
        Component(
            name="Delta Lake Spark",
            version="3.0.0",  # TODO: Make this configurable in env.py
            url=f"https://repo1.maven.org/maven2/io/delta/delta-spark_{scala_version}/3.0.0/delta-spark_{scala_version}-3.0.0.jar",
            target_dir=f"{spark_home}/jars/delta",
            filename="delta-spark.jar"
        ),
        Component(
            name="Delta Lake Storage",
            version="3.0.0",  # TODO: Make this configurable in env.py
            url=f"https://repo1.maven.org/maven2/io/delta/delta-storage/3.0.0/delta-storage-3.0.0.jar",
            target_dir=f"{spark_home}/jars/delta",
            filename="delta-storage.jar"
        ),
        # AWS Components
        Component(
            name="Hadoop AWS",
            version="3.3.2",  # TODO: Make this configurable in env.py
            url=f"https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.2/hadoop-aws-3.3.2.jar",
            target_dir=f"{spark_home}/jars/aws",
            filename="hadoop-aws.jar"
        ),
        Component(
            name="AWS SDK Bundle",
            version="1.12.262",  # TODO: Make this configurable in env.py
            url=f"https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar",
            target_dir=f"{spark_home}/jars/aws",
            filename="aws-java-sdk-bundle.jar"
        ),
        Component(
            name="AWS SDK S3",
            version="1.12.262",  # TODO: Make this configurable in env.py
            url=f"https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-s3/1.12.262/aws-java-sdk-s3-1.12.262.jar",
            target_dir=f"{spark_home}/jars/aws",
            filename="aws-java-sdk-s3.jar"
        ),
    ]

def download_component(component: Component) -> None:
    """Download a component."""
    try:
        # Create target directory
        target_dir = Path(component.target_dir)
        target_dir.mkdir(parents=True, exist_ok=True)
        
        # Download file
        target_file = target_dir / component.filename
        logger.info(f"Downloading {component.name} {component.version}...")
        subprocess.run(
            ["curl", "-L", "-o", str(target_file), component.url],
            check=True,
            capture_output=True,
            text=True
        )
        logger.info(f"Downloaded {component.name} to {target_file}")
        
    except subprocess.CalledProcessError as e:
        logger.error(f"Failed to download {component.name}: {e.stderr}")
        raise
    except Exception as e:
        logger.error(f"Failed to download {component.name}: {e}")
        raise

def download_components(env: Optional[SparkEnv] = None) -> None:
    """Download all components."""
    try:
        # Load environment configuration if not provided
        env = env or SparkEnv.load()
        
        # Get components to download
        components = get_components(env)
        
        # Download each component
        for component in components:
            download_component(component)
            
    except Exception as e:
        logger.error(f"Failed to download components: {e}")
        sys.exit(1)

if __name__ == "__main__":
    download_components()