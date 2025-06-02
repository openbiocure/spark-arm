#!/usr/bin/env python3
import os
import sys
import logging
import argparse
from pathlib import Path
from typing import Literal, NoReturn

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(levelname)s] %(asctime)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

NodeType = Literal['master', 'worker']

def setup_logging(debug: bool = False) -> None:
    """Configure logging with optional debug level."""
    level = logging.DEBUG if debug else logging.INFO
    logger.setLevel(level)

def get_node_type() -> NodeType:
    """Get the node type from environment variable."""
    node_type = os.environ.get('SPARK_NODE_TYPE', 'master')
    if node_type not in ('master', 'worker'):
        raise ValueError(f"Invalid node type: {node_type}. Must be either 'master' or 'worker'")
    return node_type

def start_master() -> NoReturn:
    """Start the Spark master node."""
    logger.info("Starting Spark master node...")
    script_path = Path('/opt/spark/scripts/start_master.py')
    if not script_path.exists():
        raise FileNotFoundError(f"Master script not found at {script_path}")
    
    # Replace current process with master script
    os.execv(sys.executable, [sys.executable, str(script_path)])

def start_worker() -> NoReturn:
    """Start the Spark worker node."""
    logger.info("Starting Spark worker node...")
    script_path = Path('/opt/spark/scripts/start_worker.py')
    if not script_path.exists():
        raise FileNotFoundError(f"Worker script not found at {script_path}")
    
    # Replace current process with worker script
    os.execv(sys.executable, [sys.executable, str(script_path)])

def start_hive() -> None:
    """Start the Hive server."""
    logger.info("Starting Hive Server2...")
    hive_home = os.environ.get('HIVE_HOME')
    if not hive_home:
        raise ValueError("HIVE_HOME environment variable is required for Hive node type")
    
    hiveserver2 = Path(hive_home) / 'bin' / 'hiveserver2'
    if not hiveserver2.exists():
        raise FileNotFoundError(f"HiveServer2 not found at {hiveserver2}")
    
    # Replace current process with HiveServer2
    os.execv(str(hiveserver2), [str(hiveserver2)])

def main() -> None:
    """Main entry point for the entrypoint script."""
    try:
        # Parse command line arguments
        parser = argparse.ArgumentParser(description='Spark cluster node entrypoint')
        parser.add_argument('--debug', action='store_true', help='Enable debug logging')
        args = parser.parse_args()

        # Setup logging
        setup_logging(args.debug)

        # Get node type and start appropriate process
        node_type = get_node_type()
        logger.info(f"Starting node as: {node_type}")

        if node_type == 'master':
            start_master()
        elif node_type == 'worker':
            start_worker()
        elif node_type == 'hive':
            start_hive()
        else:
            raise ValueError(f"Invalid node type: {node_type}. Must be either 'master', 'worker', or 'hive'")

    except Exception as e:
        logger.error(f"Failed to start node: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main() 