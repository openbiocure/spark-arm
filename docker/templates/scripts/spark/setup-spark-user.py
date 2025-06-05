#!/usr/bin/env python3
"""Set up spark user and required directories."""

import os
import logging
import subprocess
from pathlib import Path
from typing import Optional

# Add the scripts directory to Python path
scripts_dir = Path(__file__).parent
import sys
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

def run_command(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess:
    """Run a shell command and return the result."""
    try:
        result = subprocess.run(cmd, check=check, capture_output=True, text=True)
        return result
    except subprocess.CalledProcessError as e:
        logger.error(f"Command failed: {' '.join(cmd)}")
        logger.error(f"Error: {e.stderr}")
        if check:
            raise
        return e

def setup_spark_user(env: Optional[SparkEnv] = None) -> None:
    """Set up spark user and required directories.
    
    Args:
        env: SparkEnv instance. If None, will load from environment.
    """
    env = env or SparkEnv()
    spark_home = Path(env.spark_home)
    hadoop_home = Path(env.spark_home)  # Using spark home for hadoop since it's included
    
    logger.info("Setting up spark user and directories...")
    
    # Create user and group
    run_command(["groupadd", "-g", "1000", "spark"], check=False)
    run_command(["useradd", "-u", "1000", "-g", "spark", "-m", "-d", "/home/spark", "-s", "/bin/bash", "spark"], check=False)
    
    # Create directories with proper permissions
    dirs = [
        spark_home,
        hadoop_home / "lib" / "native",
        spark_home / "jars",
        spark_home / "logs",
        spark_home / "tmp"
    ]
    for d in dirs:
        d.mkdir(parents=True, exist_ok=True)
    
    # Set ownership of all directories
    run_command(["chown", "-R", "spark:spark", str(spark_home), str(hadoop_home), "/home/spark"])
    
    # Set permissions for directories
    run_command(["chmod", "755", str(spark_home), str(hadoop_home), "/home/spark"])
    
    # Ensure spark user has access to essential commands
    run_command(["chmod", "-R", "755", "/usr/bin/bash", "/usr/bin/date", "/usr/bin/mkdir"])
    
    # Ensure spark user can write to /opt/spark
    run_command(["chown", "-R", "spark:spark", "/opt/spark"])
    run_command(["chmod", "-R", "755", "/opt/spark"])
    
    # Create proper passwd and group entries while preserving root
    with open("/etc/passwd", "w") as f:
        f.write("""root:x:0:0:root:/root:/bin/bash
spark:x:1000:1000:Spark User:/home/spark:/bin/bash
""")
    
    with open("/etc/group", "w") as f:
        f.write("""root:x:0:
spark:x:1000:
""")
    
    # Verify essential commands are available and accessible
    for cmd in ["bash", "date", "mkdir"]:
        result = run_command(["su", "-", "spark", "-c", f"which {cmd}"], check=False)
        if result.returncode != 0:
            logger.error(f"{cmd} not available for spark user")
            raise RuntimeError(f"{cmd} not available for spark user")
    
    # Verify directories are accessible
    for dir_path in [spark_home / "logs", spark_home / "tmp", "/opt/spark"]:
        result = run_command(["su", "-", "spark", "-c", f"test -w {dir_path}"], check=False)
        if result.returncode != 0:
            logger.error(f"spark user cannot write to {dir_path}")
            raise RuntimeError(f"spark user cannot write to {dir_path}")
    
    logger.info("Spark user setup completed successfully")

if __name__ == "__main__":
    setup_spark_user()