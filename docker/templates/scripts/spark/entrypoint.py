#!/usr/bin/env python3
"""Spark container entrypoint script."""

import os
import sys
import logging
from pathlib import Path
from typing import Optional

# Add the scripts directory to Python path
scripts_dir = Path(__file__).parent
sys.path.append(str(scripts_dir.parent.parent.parent))

try:
    from docker_builder.env import SparkEnv, load_spark_env
except ImportError:
    raise ImportError("Could not import SparkEnv. Make sure the package is installed with 'pip install -e .'")

def setup_logging():
    """Configure logging."""
    logging.basicConfig(
        level=logging.INFO,
        format='[%(levelname)s] %(asctime)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )

def start_master(env: SparkEnv) -> None:
    """Start Spark master node."""
    from start_master import start_master as _start_master
    _start_master(env)

def start_worker(env: SparkEnv) -> None:
    """Start Spark worker node."""
    from start_worker import start_worker as _start_worker
    _start_worker(env)

def main() -> None:
    """Main entrypoint."""
    setup_logging()
    logger = logging.getLogger(__name__)
    
    try:
        # Load environment configuration
        env = load_spark_env()
        logger.info(f"Starting Spark {env.SPARK_NODE_TYPE} node")
        
        # Start appropriate node type
        if env.SPARK_NODE_TYPE == "master":
            start_master(env)
        elif env.SPARK_NODE_TYPE == "worker":
            start_worker(env)
        else:
            raise ValueError(f"Invalid SPARK_NODE_TYPE: {env.SPARK_NODE_TYPE}")
            
    except Exception as e:
        logger.error(f"Failed to start Spark node: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 