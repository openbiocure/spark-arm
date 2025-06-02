#!/usr/bin/env python3
import click
from rich.console import Console
from rich.panel import Panel
from .renderer import DockerfileRenderer

console = Console()

@click.group()
def cli():
    """Dockerfile template renderer for Spark ecosystem components."""
    pass

@cli.command()
@click.argument('component')
@click.option('--output-dir', '-o', default='docker/output',
              help='Output directory for rendered Dockerfiles')
@click.option('--config-dir', '-c', default='docker/configs',
              help='Directory containing YAML configuration files')
@click.option('--template-dir', '-t', default='docker/templates',
              help='Directory containing Jinja2 templates')
def render(component: str, output_dir: str, config_dir: str, template_dir: str):
    """Render a Dockerfile for the specified component."""
    try:
        renderer = DockerfileRenderer(config_dir=config_dir, template_dir=template_dir)
        output_path = renderer.render(component, output_dir=output_dir)
        
        console.print(Panel(
            f"[green]Successfully rendered Dockerfile for {component}[/green]\n"
            f"Output: {output_path}",
            title="Dockerfile Renderer",
            border_style="green"
        ))
    except Exception as e:
        console.print(Panel(
            f"[red]Error rendering Dockerfile:[/red]\n{str(e)}",
            title="Error",
            border_style="red"
        ))
        raise click.Abort() from e

@cli.command()
def list_components():
    """List available components that can be rendered."""
    try:
        renderer = DockerfileRenderer()
        components = [p.stem for p in renderer.template_dir.glob("*.j2")]
        
        if not components:
            console.print("[yellow]No component templates found.[/yellow]")
            return
            
        console.print(Panel(
            "\n".join(f"• {comp}" for comp in sorted(components)),
            title="Available Components",
            border_style="blue"
        ))
    except Exception as e:
        console.print(Panel(
            f"[red]Error listing components:[/red]\n{str(e)}",
            title="Error",
            border_style="red"
        ))
        raise click.Abort() from e

if __name__ == '__main__':
    cli() 