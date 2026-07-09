"""CLI entry point for the CMDI profile migrator."""

# Click command functions naturally receive one argument per CLI option,
# so the too-many-arguments limit does not make sense here.
# pylint: disable=too-many-arguments,too-many-positional-arguments

from pathlib import Path

import click
import yaml  # type: ignore[import-untyped]  # PyYAML ships no type stubs


class _ConfigGroup(click.Group):
    """Group that loads a YAML config file and feeds its values as option defaults."""

    def _load_config(self, config_path):
        if config_path is None:
            return {}
        try:
            with Path(config_path).open(encoding="utf-8") as f:
                return yaml.safe_load(f) or {}
        except FileNotFoundError as exc:
            raise click.BadParameter(
                f"config file not found: {config_path}",
                param_hint="'--config'",
            ) from exc

    def invoke(self, ctx):
        cfg = self._load_config(ctx.params.get("config"))
        ctx.default_map = {cmd: cfg for cmd in self.commands}
        super().invoke(ctx)


@click.group(cls=_ConfigGroup)
@click.option(
    "--config",
    default=None,
    type=click.Path(),
    help="Path to the config file (see config/template.yml)",
)
def cli(config):  # pylint: disable=unused-argument
    """CMDI profile migrator: convert resourceInfo records to resourceInfo-corpus-v1."""


@cli.command()
@click.option("--oai-url", required=True, help="OAI-PMH base URL")
@click.option("--set", "oai_set", required=True, help="OAI-PMH set to harvest")
@click.option("--metadata-prefix", default="cmdi", show_default=True)
@click.option(
    "--output-dir",
    required=True,
    type=click.Path(),
    help="Directory to save harvested records",
)
@click.option("--limit", default=None, type=int, help="Stop after N records")
def harvest(oai_url, oai_set, metadata_prefix, output_dir, limit):
    """Harvest CMDI records from an OAI-PMH endpoint."""
    raise NotImplementedError("harvest is not yet implemented")


@cli.command()
@click.option(
    "--input-dir",
    required=True,
    type=click.Path(exists=True),
    help="Directory from which the original records are read",
)
@click.option(
    "--output-dir",
    required=True,
    type=click.Path(),
    help="Directory to which the converted records are written",
)
@click.option("--limit", default=None, type=int, help="Stop after N records")
def convert(input_dir, output_dir, limit):
    """Convert records from resourceInfo to resourceInfo-corpus-v1."""
    raise NotImplementedError("convert is not yet implemented")


@cli.command()
@click.option(
    "--input-dir",
    required=True,
    type=click.Path(exists=True),
    help="Directory containing the records to be validated",
)
@click.option(
    "--schema",
    default=None,
    type=click.Path(),
    help="Path to XSD schema",
)
def validate(input_dir, schema):
    """Validate records against the new-profile XSD schema."""
    raise NotImplementedError("validate is not yet implemented")


@cli.command()
@click.option(
    "--input-dir",
    required=True,
    type=click.Path(exists=True),
    help="Directory of from which to read the records to be uploaded",
)
@click.option("--upload-url", required=True, help="URL used when uploading the records")
@click.option(
    "--dry-run",
    is_flag=True,
    default=True,
    help="Print what would be uploaded without uploading",
)
@click.option("--limit", default=None, type=int, help="Stop after N records")
def upload(input_dir, upload_url, dry_run, limit):
    """Upload converted records to the repository."""
    raise NotImplementedError("upload is not yet implemented")


@cli.command()
@click.option("--oai-url", required=True, help="OAI-PMH base URL")
@click.option("--set", "oai_set", required=True, help="OAI-PMH set to harvest")
@click.option("--upload-url", required=True, help="URL used when uploading the records")
@click.option(
    "--input-dir",
    required=True,
    type=click.Path(),
    help="Directory to save harvested records",
)
@click.option(
    "--output-dir",
    required=True,
    type=click.Path(),
    help="Directory to write converted records",
)
@click.option(
    "--dry-run",
    is_flag=True,
    default=False,
    help="Harvest and convert but do not upload",
)
@click.option("--limit", default=None, type=int, help="Stop after N records")
def run(oai_url, oai_set, upload_url, input_dir, output_dir, dry_run, limit):
    """Run the full pipeline: harvest, convert, validate and upload"""
    raise NotImplementedError("run is not yet implemented")
