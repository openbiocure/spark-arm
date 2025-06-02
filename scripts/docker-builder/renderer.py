import os
import yaml
from pathlib import Path
from typing import Dict, Any
from jinja2 import Environment, FileSystemLoader
from dotenv import load_dotenv

class DockerfileRenderer:
    def __init__(self, config_dir: str = "docker/configs", template_dir: str = "docker/templates"):
        self.config_dir = Path(config_dir)
        self.template_dir = Path(template_dir)
        self.env = Environment(
            loader=FileSystemLoader(str(self.template_dir)),
            trim_blocks=True,
            lstrip_blocks=True
        )
        
        # Load environment variables
        load_dotenv()
        
        # Load configurations
        self.versions = self._load_yaml("versions.yaml")
        
    def _load_yaml(self, filename: str) -> Dict[str, Any]:
        """Load a YAML configuration file."""
        with open(self.config_dir / filename) as f:
            return yaml.safe_load(f)
    
    def _get_env_vars(self) -> Dict[str, str]:
        """Get environment variables that override config values."""
        return {k: v for k, v in os.environ.items() if k.startswith(("SPARK_", "HIVE_", "POSTGRES_", "AWS_", "MINIO_"))}
    
    def render(self, component: str, output_dir: str = "docker/output") -> str:
        """Render a Dockerfile template for the specified component."""
        # Get template
        template = self.env.get_template(f"{component}.j2")
        
        # Prepare context
        context = {
            "versions": self.versions["versions"],
            "urls": self.versions["urls"],
            "components": self.versions["components"],
            "env": self._get_env_vars()
        }
        
        # Render template
        output = template.render(**context)
        
        # Ensure output directory exists
        output_path = Path(output_dir) / component
        output_path.mkdir(parents=True, exist_ok=True)
        
        # Write rendered Dockerfile
        dockerfile_path = output_path / "Dockerfile"
        with open(dockerfile_path, "w") as f:
            f.write(output)
            
        return str(dockerfile_path) 