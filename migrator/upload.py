"""Upload converted CMDI records to a Comedi repository."""

from pathlib import Path

import click
import requests
from lxml import etree  # type: ignore[import-untyped]

_ENVELOPE_NS = "http://www.clarin.eu/cmd/1"
_SELFLINK_TAG = f"{{{_ENVELOPE_NS}}}MdSelfLink"


def _rewrite_selflink(xml_bytes, prefix):
    """Return xml_bytes with the MdSelfLink value prefixed.

    If prefix is empty the bytes are returned unchanged.
    The prefix is inserted after 'urn:nbn:fi:', before the 'lb-' segment when present:
      urn:nbn:fi:lb-0123456        ->  urn:nbn:fi:{prefix}-lb-0123456
      urn:nbn:fi:something-else    ->  urn:nbn:fi:{prefix}-something-else
    Raises ValueError if the selflink does not contain 'urn:nbn:fi:'.
    """
    if not prefix:
        return xml_bytes
    doc = etree.fromstring(xml_bytes)
    el = doc.find(f".//{_SELFLINK_TAG}")
    if el is not None and el.text:
        text = el.text.strip()
        lb_idx = text.find("lb-")
        if lb_idx != -1:
            el.text = text[:lb_idx] + prefix + "-" + text[lb_idx:]
        else:
            nbn_idx = text.find("urn:nbn:fi:")
            if nbn_idx == -1:
                raise ValueError(f"MdSelfLink does not contain 'urn:nbn:fi:': {text!r}")
            insert_at = nbn_idx + len("urn:nbn:fi:")
            el.text = text[:insert_at] + prefix + "-" + text[insert_at:]
    return etree.tostring(doc, xml_declaration=True, encoding="UTF-8")


def _rewrite_filename(filename, prefix):
    """Insert prefix into filename: "lb-0123456.xml" -> "{prefix}-lb-0123456.xml"."""
    if not prefix:
        return filename
    return f"{prefix}-{filename}"


def upload_record(
    xml_bytes, upload_url, upload_group, session_id, filename, prefix, dry_run
):
    """Upload a single record. Returns the response status code, or None on dry run."""
    patched = _rewrite_selflink(xml_bytes, prefix)
    upload_filename = _rewrite_filename(filename, prefix)
    if dry_run:
        click.echo(f"  [dry-run] would upload as {upload_filename}")
        return None
    resp = requests.post(
        upload_url,
        params={"group": upload_group, "session-id": session_id},
        files={"file": (upload_filename, patched, "application/xml")},
        timeout=60,
    )
    resp.raise_for_status()
    response_json = resp.json()
    if "error" in response_json:
        raise requests.HTTPError(response_json["error"], response=resp)
    return resp.status_code


def upload_dir(
    converted_dir,
    upload_url,
    upload_group,
    session_id,
    prefix,
    dry_run,
    limit=None,
    quiet=False,
):
    """Upload all XML records in converted_dir.

    Returns (uploaded_count, failed_count).
    """
    uploaded = 0
    failed = 0
    paths = sorted(Path(converted_dir).glob("*.xml"))
    if limit is not None:
        paths = paths[:limit]
    for src in paths:
        xml_bytes = src.read_bytes()
        if not quiet or dry_run:
            click.echo(src.name)
        try:
            upload_record(
                xml_bytes,
                upload_url,
                upload_group,
                session_id,
                src.name,
                prefix,
                dry_run,
            )
            uploaded += 1
        except requests.HTTPError as exc:
            failed += 1
            click.echo(f"  FAILED: {exc}")
    return uploaded, failed
