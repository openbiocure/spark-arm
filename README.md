# Spark Docker Builder

A Python-based tool for building and managing Docker containers for Apache Spark components.

## Features

- Jinja2-based Dockerfile templating
- YAML configuration management
- Support for Spark master and worker nodes
- Python-based container management scripts
- Secure user setup and environment configuration

## Installation

```bash
# Create and activate a virtual environment (recommended)
python -m venv venv
source venv/bin/activate  # On Unix/macOS
# or
.\venv\Scripts\activate  # On Windows

# Install in development mode
pip install -e .
```

## Usage

The package provides a command-line tool `docker-builder` for managing Docker builds:

```bash
# Build a specific component
docker-builder build spark

# List available components
docker-builder list

# Show help
docker-builder --help
```

## Project Structure

```
.
├── docker/
│   └── templates/          # Jinja2 templates for Dockerfiles
│       ├── spark.j2       # Spark component template
│       └── scripts/       # Container management scripts
├── scripts/
│   └── docker_builder/    # Python package for Docker management
│       ├── __init__.py
│       ├── cli.py         # Command-line interface
│       └── renderer.py    # Template rendering logic
├── pyproject.toml         # Project metadata and dependencies
└── README.md             # This file
```

## Development

This project uses modern Python packaging with `pyproject.toml`. Key dependencies include:

- PyYAML: For YAML configuration parsing
- Jinja2: For template rendering
- typing-extensions: For enhanced type hints
- pathlib: For file path handling
- argparse: For command-line argument parsing

## License

MIT License - see LICENSE file for details 