"""Validate converted CMDI records against the destination profile XSD."""

# pylint: disable=c-extension-no-member

from pathlib import Path

import click
from lxml import etree  # type: ignore[import-untyped]  # lxml ships no type stubs

_SCHEMAS_DIR = Path(__file__).parent / "schemas"

_BUNDLED = {
    "http://www.w3.org/2001/xml.xsd": _SCHEMAS_DIR / "xml.xsd",
    "https://infra.clarin.eu/CMDI/1.x/xsd/cmd-envelop.xsd": _SCHEMAS_DIR
    / "cmd-envelop.xsd",
}


class _BundledSchemaResolver(etree.Resolver):
    """Return local copies of external schemas that may be unreachable."""

    def resolve(self, url, _id, context):
        path = _BUNDLED.get(url)
        if path is not None:
            return self.resolve_filename(str(path), context)
        return None


def load_schema(schema_path):
    """Parse and return an XMLSchema from schema_path.

    Raises ClickException if the schema fails to compile.
    """
    parser = etree.XMLParser()
    parser.resolvers.add(_BundledSchemaResolver())
    try:
        return etree.XMLSchema(etree.parse(str(schema_path), parser))
    except etree.XMLSchemaParseError as exc:
        raise click.ClickException(
            f"Schema failed to compile: {schema_path}\n{exc}"
        ) from exc


def validate_record(xml_bytes, schema):
    """Validate a single record. Returns a list of error strings, empty if valid."""
    doc = etree.fromstring(xml_bytes)
    schema.validate(doc)
    return [str(e) for e in schema.error_log]


def validate_dir(converted_dir, schema_path, quiet=False):
    """Validate all XML records in converted_dir against schema_path.

    Errors are always printed. OK lines are suppressed when quiet=True.
    Returns (valid_count, invalid_count).
    """
    schema = load_schema(schema_path)
    valid = 0
    invalid = 0
    for src in sorted(Path(converted_dir).glob("*.xml")):
        errors = validate_record(src.read_bytes(), schema)
        if errors:
            invalid += 1
            click.echo(f"{src.name}: INVALID")
            for err in errors:
                click.echo(f"  {err}")
        else:
            valid += 1
            if not quiet:
                click.echo(f"{src.name}: OK")
    return valid, invalid
