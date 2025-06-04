#!/usr/bin/env python3
"""Script to download and manage Spark and its dependencies."""

import os
import sys
import logging
import requests
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional
from requests.exceptions import RequestException

# Add the scripts directory to Python path
scripts_dir = Path(__file__).parent
sys.path.append(str(scripts_dir.parent.parent.parent))

try:
    from docker_builder.env import SparkEnv, load_spark_env
except ImportError:
    raise ImportError("Could not import SparkEnv. Make sure the package is installed with 'pip install -e .'")

# ANSI color codes
RED = '\033[91m'
BOLD = '\033[1m'
YELLOW = '\033[93m'
RESET = '\033[0m'
BOX_TOP = '╔' + '═' * 98 + '╗'
BOX_MID = '║' + ' ' * 98 + '║'
BOX_BOT = '╚' + '═' * 98 + '╝'

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
    filename: Optional[str] = None

    @property
    def download_path(self) -> Path:
        """Get the full download path."""
        return Path(self.target_dir) / (self.filename or self.url.split('/')[-1])

def print_url_warning(component: Component, status_code: int) -> None:
    """Print a prominent warning message about URL changes."""
    status_msg = f"HTTP {status_code}" if status_code > 0 else "Connection Error"
    message = [
        f"{RED}{BOLD}{BOX_TOP}",
        f"{BOX_MID}",
        f"║{' ' * 35}🚨 CRITICAL ERROR 🚨{' ' * 35}║",
        f"{BOX_MID}",
        f"║{' ' * 25}DOWNLOAD URL HAS CHANGED OR IS INACCESSIBLE{' ' * 25}║",
        f"{BOX_MID}",
        f"║{' ' * 5}Component: {component.name} (Version: {component.version}){' ' * (83 - len(component.name) - len(component.version))}║",
        f"║{' ' * 5}URL: {component.url}{' ' * (93 - len(component.url))}║",
        f"║{' ' * 5}Status: {status_msg}{' ' * (93 - len(status_msg))}║",
        f"{BOX_MID}",
        f"║{' ' * 5}{YELLOW}ACTION REQUIRED:{RESET}{RED}{BOLD} Please check if the URL has been updated in the repository{' ' * 20}║",
        f"║{' ' * 5}         You may need to update the URL in download-jars.py{' ' * 35}║",
        f"{BOX_MID}",
        f"{BOX_BOT}{RESET}"
    ]
    print('\n'.join(message), file=sys.stderr)
    print(f"\n{RED}{BOLD}Build process will now exit due to URL error.{RESET}\n", file=sys.stderr)

def check_url(component: Component) -> bool:
    """Check if URL is accessible."""
    try:
        response = requests.head(component.url, allow_redirects=True, timeout=10)
        if response.status_code == 200:
            return True
        print_url_warning(component, response.status_code)
        return False
    except RequestException as e:
        logger.error(f"URL check failed with error: {e}")
        print_url_warning(component, 0)  # Use 0 to indicate connection error
        return False

def get_components(env: SparkEnv) -> List[Component]:
    """Get list of components to download."""
    scala_version = os.environ.get("SCALA_VERSION", "2.12")
    return [
        # Apache Spark (without Hadoop)
        Component(
            name="Apache Spark",
            version="3.5.3",
            url="https://archive.apache.org/dist/spark/spark-3.5.3/spark-3.5.3-bin-without-hadoop.tgz",
            target_dir="/tmp/downloads",
            filename="spark.tgz"
        ),
        # Apache Hadoop
        Component(
            name="Apache Hadoop",
            version="3.3.2",
            url="https://archive.apache.org/dist/hadoop/common/hadoop-3.3.2/hadoop-3.3.2.tar.gz",
            target_dir="/tmp/downloads",
            filename="hadoop.tgz"
        ),
        # Delta Lake Components
        Component(
            name="Delta Lake Core",
            version="3.3.2",
            url=f"https://repo1.maven.org/maven2/io/delta/delta-core_{scala_version}/3.3.2/delta-core_{scala_version}-3.3.2.jar",
            target_dir=f"{env.SPARK_HOME}/jars/delta",
            filename="delta-core.jar"
        ),
        Component(
            name="Delta Lake Spark",
            version="3.3.2",
            url=f"https://repo1.maven.org/maven2/io/delta/delta-spark_{scala_version}/3.3.2/delta-spark_{scala_version}-3.3.2.jar",
            target_dir=f"{env.SPARK_HOME}/jars/delta",
            filename="delta-spark.jar"
        ),
        Component(
            name="Delta Lake Storage",
            version="3.3.2",
            url="https://repo1.maven.org/maven2/io/delta/delta-storage/3.3.2/delta-storage-3.3.2.jar",
            target_dir=f"{env.SPARK_HOME}/jars/delta",
            filename="delta-storage.jar"
        ),
        # AWS Components
        Component(
            name="Hadoop AWS",
            version="3.3.2",
            url="https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.2/hadoop-aws-3.3.2.jar",
            target_dir=f"{env.SPARK_HOME}/jars/aws",
            filename="hadoop-aws.jar"
        ),
        Component(
            name="AWS SDK Bundle",
            version="1.11.1026",
            url="https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.11.1026/aws-java-sdk-bundle-1.11.1026.jar",
            target_dir=f"{env.SPARK_HOME}/jars/aws",
            filename="aws-java-sdk-bundle.jar"
        ),
        Component(
            name="AWS SDK S3",
            version="1.12.262",
            url="https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-s3/1.12.262/aws-java-sdk-s3-1.12.262.jar",
            target_dir=f"{env.SPARK_HOME}/jars/aws",
            filename="aws-java-sdk-s3.jar"
        ),
    ]

def download_component(component: Component) -> None:
    """Download a single component."""
    try:
        # Create target directory if it doesn't exist
        os.makedirs(component.target_dir, exist_ok=True)
        
        # Check URL first
        logger.info(f"Checking URL for {component.name} {component.version}...")
        if not check_url(component):
            raise FileNotFoundError(f"URL not accessible: {component.url}")
        
        # Download the component
        logger.info(f"Downloading {component.name} {component.version}...")
        os.system(f"wget -q {component.url} -O {component.download_path}")
        
        # Verify download
        if not component.download_path.exists():
            raise FileNotFoundError(f"Failed to download {component.name}")
        
        logger.info(f"Successfully downloaded {component.name} {component.version}")
        
    except Exception as e:
        logger.error(f"Failed to download {component.name}: {e}")
        raise

def main():
    """Main entry point."""
    try:
        # Load environment configuration
        env = load_spark_env()
        
        # Get components to download
        components = get_components(env)
        
        # Download each component
        for component in components:
            download_component(component)
            
    except Exception as e:
        logger.error(f"Failed to download components: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 