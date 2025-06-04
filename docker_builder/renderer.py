"""Dockerfile template renderer for Spark components."""

import os
from pathlib import Path
from typing import Dict, Any, List
from dotenv import load_dotenv
import yaml  # type: ignore # pyright: ignore
from jinja2 import Environment, FileSystemLoader, select_autoescape, Template
import shutil


class DockerfileRenderer:
    """Handles rendering of Dockerfile templates for Spark components."""

    def __init__(self, config_path: str = 'docker/configs/versions.yaml'):
        """Initialize the renderer with configuration and template paths."""
        self.base_dir = Path(__file__).parent.parent
        self.template_dir = self.base_dir / 'docker' / 'templates'
        self.config_path = Path(config_path)
        
        # Load environment variables
        load_dotenv()
        
        # Initialize Jinja2 environment
        self.env = Environment(
            loader=FileSystemLoader(str(self.template_dir)),
            autoescape=select_autoescape(['html', 'xml']),
            trim_blocks=True,
            lstrip_blocks=True
        )
        
        # Load configuration
        self.config = self._load_config()

    def _validate_config(self, config: dict) -> None:
        """Validate configuration structure and required fields."""
        if not isinstance(config, dict):
            raise ValueError("Config must be a dictionary")
        
        # Validate versions section
        versions = config.get('versions')
        if not versions or not isinstance(versions, dict):
            raise ValueError("Config must have a 'versions' section with component versions")
        
        required_versions = ['spark', 'hadoop', 'scala', 'java', 'delta']
        for version in required_versions:
            if version not in versions:
                raise ValueError(f"Missing required version: {version}")
        
        # Validate components section
        components = config.get('components')
        if not components or not isinstance(components, dict):
            raise ValueError("Config must have a 'components' section with component configurations")
        
        # Validate spark component (required)
        spark = components.get('spark')
        if not spark or not isinstance(spark, dict):
            raise ValueError("Config must have a 'spark' component configuration")
        
        required_spark_fields = ['home', 'delta_log_store', 's3a']
        for field in required_spark_fields:
            if field not in spark:
                raise ValueError(f"Spark component missing required field: {field}")
        
        # Validate s3a settings
        s3a = spark.get('s3a')
        if not s3a or not isinstance(s3a, dict):
            raise ValueError("Spark component must have 's3a' settings")
        
        required_s3a_fields = ['path_style_access', 'connection_ssl_enabled']
        for field in required_s3a_fields:
            if field not in s3a:
                raise ValueError(f"Spark s3a settings missing required field: {field}")

    def _load_config(self) -> dict:
        """Load and validate configuration from YAML file."""
        if not self.config_path.exists():
            raise ValueError(f"Config file not found: {self.config_path}")
        
        try:
            with open(self.config_path) as f:
                config = yaml.safe_load(f)
                if not config:
                    raise ValueError("Config file is empty")
                
                # Validate config structure
                self._validate_config(config)
                return config
                
        except yaml.YAMLError as e:
            raise ValueError(f"Invalid YAML configuration: {str(e)}")
        except Exception as e:
            raise RuntimeError(f"Failed to load configuration: {str(e)}")

    def _resolve_nested_templates(self, value: str, context: Dict[str, Any]) -> str:
        """Resolve nested template variables in a string."""
        if not isinstance(value, str) or '{{' not in value:
            return value
        
        template = Template(value)
        return template.render(**context)

    def _process_urls(self, urls: Dict[str, Any], context: Dict[str, Any]) -> Dict[str, Any]:
        """Process URLs to resolve nested template variables."""
        return {
            key: self._process_urls(value, context) if isinstance(value, dict)
            else self._resolve_nested_templates(value, context)
            for key, value in urls.items()
        }

    def list_components(self) -> List[str]:
        """List available component templates."""
        return [p.stem for p in self.template_dir.glob("*.j2")]

    def _get_template_context(self) -> Dict[str, Any]:
        """Get the template context from config and environment."""
        return {
            'versions': self.config.get('versions', {}),
            'components': self.config.get('components', {}),
            'env': os.environ
        }

    def render(self, component: str, output_dir: str = '.') -> Path:
        """Render a Dockerfile and configs for the specified component."""
        template_path = f"{component}.j2"
        if not (self.template_dir / template_path).exists():
            raise ValueError(f"Template not found for component: {component}")
        
        try:
            context = self._get_template_context()
            
            # Create output directory structure
            output_path = Path(output_dir)
            output_path.mkdir(parents=True, exist_ok=True)
            (output_path / 'config').mkdir(exist_ok=True)
            
            # Copy template files
            scripts_dir = output_path / 'scripts' / component
            conf_dir = output_path / 'conf'
            scripts_dir.mkdir(parents=True, exist_ok=True)
            conf_dir.mkdir(exist_ok=True)
            
            # Copy scripts
            for script in (self.template_dir / 'scripts' / component).glob('*.py'):
                shutil.copy2(script, scripts_dir / script.name)
            for script in (self.template_dir / 'scripts' / component).glob('*.sh'):
                shutil.copy2(script, scripts_dir / script.name)
            
            # Copy config files
            for conf in (self.template_dir / 'conf').glob('*'):
                shutil.copy2(conf, conf_dir / conf.name)
            
            # Render Dockerfile
            template = self.env.get_template(template_path)
            output = template.render(**context)
            
            # Write Dockerfile
            dockerfile_path = output_path / f"Dockerfile.{component}"
            with open(dockerfile_path, 'w') as f:
                f.write(output)
            
            # Generate and write component config
            component_config = {
                "env": {k: v for k, v in os.environ.items() if v is not None},
                "versions": self.config["versions"],
                "components": self.config["components"]
            }
            config_path = output_path / "config" / f"{component}.yml"
            with open(config_path, "w") as f:
                yaml.dump(component_config, f, default_flow_style=False)
            
            # Update Dockerfile to copy config
            with open(dockerfile_path, "a") as f:
                f.write("\n# Copy component config\n")
                f.write(f"COPY config/{component}.yml /opt/{component}/config/\n")
                f.write(f"COPY scripts/{component} /opt/{component}/scripts/\n")
                
            return dockerfile_path
            
        except Exception as e:
            raise RuntimeError(f"Failed to render {component}: {str(e)}") 