"""Convert CMDI resourceInfo records to resourceInfo-corpus-v1 using XSLT."""

# lxml is a C extension - pylint cannot introspect its members at analysis time.
# pylint: disable=c-extension-no-member
# The loop pattern for processing a directory of records is intentionally similar
# across harvest and convert - shared abstraction would add complexity without value.
# pylint: disable=duplicate-code

from pathlib import Path

import click
from lxml import etree  # type: ignore[import-untyped]  # lxml ships no type stubs

_XSLT_DIR = Path(__file__).parent.parent / "xslt"

_transforms = {
    "1.1": etree.XSLT(
        etree.parse(str(_XSLT_DIR / "resourceinfo_to_corpus_v1_cmdi11.xsl"))
    ),
    "1.2": etree.XSLT(
        etree.parse(str(_XSLT_DIR / "resourceinfo_to_corpus_v1_cmdi12.xsl"))
    ),
}


def _detect_version(doc):
    """Return the CMDI version string ('1.1' or '1.2') from a parsed document."""
    return doc.get("CMDVersion", "1.1")


def convert(xml_bytes):
    """Convert a single CMDI resourceInfo record to resourceInfo-corpus-v1.

    Returns converted XML as bytes. Raises RuntimeError if the XSLT reports errors.
    """
    doc = etree.fromstring(xml_bytes)
    transform = _transforms[_detect_version(doc)]
    result = transform(doc)
    if transform.error_log:
        raise RuntimeError(str(transform.error_log))
    return etree.tostring(
        result, xml_declaration=True, encoding="UTF-8", pretty_print=True
    )


def convert_dir(raw_dir, converted_dir, limit, quiet=False):
    """Convert all XML records in raw_dir and write results to converted_dir.

    Returns the number of records converted.
    """
    inp = Path(raw_dir)
    out = Path(converted_dir)
    out.mkdir(parents=True, exist_ok=True)

    count = 0
    for src in sorted(inp.glob("*.xml")):
        (out / src.name).write_bytes(convert(src.read_bytes()))
        count += 1
        if not quiet:
            click.echo(f"\rConverted {count} records...", nl=False)
        if limit and count >= limit:
            break

    if not quiet:
        click.echo("")
    return count
