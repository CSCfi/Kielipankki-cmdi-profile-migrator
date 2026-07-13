"""OAI-PMH harvester: fetch CMDI records from a repository."""

# lxml is a C extension - pylint cannot introspect its members at analysis time.
# pylint: disable=c-extension-no-member
# harvest() receives one argument per CLI option, so the limit does not apply.
# pylint: disable=too-many-arguments,too-many-positional-arguments

from pathlib import Path

import click
from lxml import etree  # type: ignore[import-untyped]  # lxml ships no type stubs
from sickle import Sickle  # type: ignore[import-untyped]  # sickle ships no type stubs

OAI_METADATA_TAG = "{http://www.openarchives.org/OAI/2.0/}metadata"


def _filename(identifier):
    """Determine the file name for a record based on its identifier.

    OAI identifiers have the form oai:{repository}:{local-id}. Only the
    local-id part is used for the filename.
    """
    return f'{identifier.split(":")[-1]}.xml'


def _get_cmdi(record):
    """Extract the CMDI record element from a Sickle Record."""
    metadata = record.xml.find(OAI_METADATA_TAG)
    if metadata is not None and len(metadata):
        return metadata[0]
    return None


def _save_record(record_el, dest):
    """Serialise a record element to dest as UTF-8 XML."""
    dest.write_bytes(etree.tostring(record_el, xml_declaration=True, encoding="UTF-8"))


def harvest(oai_url, oai_set, metadata_prefix, output_dir, limit, quiet=False):
    """Harvest records from an OAI-PMH endpoint and save them to output_dir.

    Returns the number of records saved.
    """
    out = Path(output_dir)
    out.mkdir(parents=True, exist_ok=True)

    sickle = Sickle(oai_url)
    records = sickle.ListRecords(
        metadataPrefix=metadata_prefix, set=oai_set, ignore_deleted=True
    )

    count = 0
    for record in records:
        cmdi = _get_cmdi(record)
        if cmdi is None:
            continue
        _save_record(cmdi, out / _filename(record.header.identifier))
        count += 1
        if not quiet:
            click.echo(f"\rHarvested {count} records...", nl=False)
        if limit and count >= limit:
            break

    if not quiet:
        click.echo("")
    return count
