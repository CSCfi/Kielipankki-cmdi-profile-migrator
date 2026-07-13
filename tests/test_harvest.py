"""Tests for the OAI-PMH harvester."""

# pytest fixtures are injected by name, which pylint sees as shadowing the
# module-level fixture function.
# pylint: disable=redefined-outer-name
# lxml is a C extension - pylint cannot introspect its members at analysis time.
# pylint: disable=c-extension-no-member
from unittest.mock import MagicMock, patch

from lxml import etree  # type: ignore[import-untyped]  # lxml ships no type stubs

from migrator.harvest import _filename, _get_cmdi, harvest

OAI_NS = "http://www.openarchives.org/OAI/2.0/"
CMDI_NS = "http://www.clarin.eu/cmd/"

OAI_URL = "https://clarino.uib.no/oai"
OAI_SET = "FIN-CLARIN"
METADATA_PREFIX = "cmdi"


def _make_oai_record(identifier, cmdi_el=None):
    """Build a mock Sickle Record with an OAI-PMH XML envelope.

    record.xml is an <oai:record> element; record.header.identifier is set to
    identifier. If cmdi_el is given it is appended as the sole child of
    <oai:metadata>.
    """
    root = etree.Element(f"{{{OAI_NS}}}record")
    header = etree.SubElement(root, f"{{{OAI_NS}}}header")
    etree.SubElement(header, f"{{{OAI_NS}}}identifier").text = identifier
    metadata = etree.SubElement(root, f"{{{OAI_NS}}}metadata")
    if cmdi_el is not None:
        metadata.append(cmdi_el)

    record = MagicMock()
    record.xml = root
    record.header.identifier = identifier
    return record


def _minimal_cmdi():
    """Return a minimal CMDI 1.1 element matching the real records' structure."""
    return etree.fromstring(
        f'<CMD xmlns="{CMDI_NS}" CMDVersion="1.1">'
        "<Header>"
        "<MdSelfLink>urn:nbn:fi:lb-1</MdSelfLink>"
        "<MdProfile>clarin.eu:cr1:p_1361876010571</MdProfile>"
        "</Header>"
        "<Resources><ResourceProxyList/></Resources>"
        "<Components><resourceInfo/></Components>"
        "</CMD>".encode()
    )


class TestFilename:
    """Tests for _filename()."""

    def test_extracts_local_id(self):
        """lb-N local ID becomes the filename."""
        assert _filename("oai:clarino.uib.no:lb-1") == "lb-1.xml"

    def test_extracts_local_id_longer_id(self):
        """A second identifier also maps to the correct filename."""
        assert (
            _filename("oai:clarino.uib.no:lb-123456-postfix") == "lb-123456-postfix.xml"
        )


class TestGetCmdi:
    """Tests for _get_cmdi()."""

    def test_returns_cmdi_element_when_present(self):
        """Returns the first child of <metadata> when a CMDI payload exists."""
        cmdi = _minimal_cmdi()
        record = _make_oai_record("oai:clarino.uib.no:lb-1", cmdi)
        result = _get_cmdi(record)
        assert result is not None
        assert result.tag == cmdi.tag

    def test_returns_none_when_metadata_is_empty(self):
        """Returns None when <metadata> has no children."""
        record = _make_oai_record("oai:clarino.uib.no:lb-1")
        assert _get_cmdi(record) is None


class TestHarvest:
    """Tests for harvest()."""

    def test_saves_records_as_xml_files(self, tmp_path):
        """Each harvested record is written to a file named after its local ID."""
        records = [
            _make_oai_record("oai:clarino.uib.no:lb-1", _minimal_cmdi()),
            _make_oai_record("oai:clarino.uib.no:lb-2", _minimal_cmdi()),
        ]
        with patch("migrator.harvest.Sickle") as mock_sickle:
            mock_sickle.return_value.ListRecords.return_value = iter(records)
            count = harvest(OAI_URL, OAI_SET, METADATA_PREFIX, str(tmp_path), None)

        assert count == 2
        assert (tmp_path / "lb-1.xml").exists()
        assert (tmp_path / "lb-2.xml").exists()

    def test_creates_output_directory(self, tmp_path):
        """harvest() creates the output directory when it does not yet exist."""
        out = tmp_path / "records" / "raw"
        with patch("migrator.harvest.Sickle") as mock_sickle:
            mock_sickle.return_value.ListRecords.return_value = iter([])
            harvest(OAI_URL, OAI_SET, METADATA_PREFIX, str(out), None)

        assert out.is_dir()

    def test_limit_stops_after_n_records(self, tmp_path):
        """harvest() stops saving after `limit` records have been written."""
        ids = [f"oai:clarino.uib.no:lb-{i}" for i in range(1, 6)]
        records = [_make_oai_record(i, _minimal_cmdi()) for i in ids]
        with patch("migrator.harvest.Sickle") as mock_sickle:
            mock_sickle.return_value.ListRecords.return_value = iter(records)
            count = harvest(OAI_URL, OAI_SET, METADATA_PREFIX, str(tmp_path), 2)

        assert count == 2

    def test_saved_file_is_well_formed_xml(self, tmp_path):
        """Files written by harvest() are parseable, well-formed XML."""
        cmdi = _minimal_cmdi()
        records = [_make_oai_record("oai:clarino.uib.no:lb-1", cmdi)]
        with patch("migrator.harvest.Sickle") as mock_sickle:
            mock_sickle.return_value.ListRecords.return_value = iter(records)
            harvest(OAI_URL, OAI_SET, METADATA_PREFIX, str(tmp_path), None)

        saved = etree.parse(str(tmp_path / "lb-1.xml"))
        assert saved.getroot().tag == cmdi.tag
