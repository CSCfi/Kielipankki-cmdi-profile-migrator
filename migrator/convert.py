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

_SUPPORTED_PROFILES = {"clarin.eu:cr1:p_1361876010571"}

_transforms = {
    "1.1": etree.XSLT(
        etree.parse(str(_XSLT_DIR / "resourceinfo_to_corpus_v1_cmdi11.xsl"))
    ),
}


def _detect_version(doc):
    """Return the CMDI version string ('1.1' or '1.2') from a parsed document."""
    return doc.get("CMDVersion", "1.1")


def _detect_profile(doc):
    """Return the MdProfile value from the document header, or None if absent."""
    ns = {"cmd11": "http://www.clarin.eu/cmd/", "cmd": "http://www.clarin.eu/cmd/1"}
    el = doc.find(".//cmd11:MdProfile", ns)
    if el is None:
        el = doc.find(".//cmd:MdProfile", ns)
    return el.text.strip() if el is not None and el.text else None


def convert(xml_bytes):
    """Convert a single CMDI resourceInfo record to resourceInfo-corpus-v1.

    Returns converted XML as bytes. Raises RuntimeError if the XSLT reports errors.
    """
    doc = etree.fromstring(xml_bytes)
    version = _detect_version(doc)
    if version not in _transforms:
        raise ValueError(f"No stylesheet available for CMDI version {version!r}")
    transform = _transforms[version]
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
    skip_messages = []
    for src in sorted(inp.glob("*.xml")):
        doc = etree.fromstring(src.read_bytes())
        profile = _detect_profile(doc)
        if profile not in _SUPPORTED_PROFILES:
            skip_messages.append(
                f"Skipping {src.name}: unsupported profile {profile!r}"
            )
            continue
        (out / src.name).write_bytes(convert(src.read_bytes()))
        count += 1
        if not quiet:
            click.echo(f"\rConverted {count} records...", nl=False)
        if limit and count >= limit:
            break

    if not quiet:
        click.echo("")
        for msg in skip_messages:
            click.echo(msg)
    return count, len(skip_messages)
