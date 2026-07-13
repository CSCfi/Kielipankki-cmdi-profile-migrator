"""Tests for CMDI 1.2 resourceInfo -> resourceInfo-corpus-v1 conversion."""

# lxml is a C extension - pylint cannot introspect its members at analysis time.
# pylint: disable=c-extension-no-member

from lxml import etree  # type: ignore[import-untyped]  # lxml ships no type stubs

from migrator.convert import convert

# CMDI 1.2 uses separate namespaces for envelope and profile elements.
CMD_NS = "http://www.clarin.eu/cmd/1"
OLD_PROFILE = "clarin.eu:cr1:p_1361876010571"
NEW_PROFILE = "clarin.eu:cr1:p_1778593302234"
OLD_PROFILE_NS = f"http://www.clarin.eu/cmd/1/profiles/{OLD_PROFILE}"
NEW_PROFILE_NS = f"http://www.clarin.eu/cmd/1/profiles/{NEW_PROFILE}"
_REGISTRY = "https://catalog.clarin.eu/ds/ComponentRegistry/rest/registry/1.2/profiles"
_OLD_XSD = f"{_REGISTRY}/{OLD_PROFILE}/xsd"

_MINIMAL_RECORD_12 = f"""<?xml version='1.0' encoding='UTF-8'?>
<cmd:CMD xmlns:cmd="{CMD_NS}"
         xmlns:cmdp="{OLD_PROFILE_NS}"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         CMDVersion="1.2"
         xsi:schemaLocation="{CMD_NS} https://infra.clarin.eu/CMDI/1.x/xsd/cmd-envelop.xsd
           {OLD_PROFILE_NS} {_OLD_XSD}">
  <cmd:Header>
    <cmd:MdCreator>Test</cmd:MdCreator>
    <cmd:MdCreationDate>2026-01-01</cmd:MdCreationDate>
    <cmd:MdSelfLink>urn:nbn:fi:lb-1</cmd:MdSelfLink>
    <cmd:MdProfile>{OLD_PROFILE}</cmd:MdProfile>
  </cmd:Header>
  <cmd:Resources><cmd:ResourceProxyList/></cmd:Resources>
  <cmd:IsPartOfList/>
  <cmd:Components>
    <cmdp:resourceInfo>
      <cmdp:identificationInfo>
        <cmdp:resourceName xml:lang="en">Test Corpus</cmdp:resourceName>
        <cmdp:resourceShortName xml:lang="en">test-corpus</cmdp:resourceShortName>
        <cmdp:description xml:lang="en">A test corpus.</cmdp:description>
        <cmdp:metaShareId>n/a</cmdp:metaShareId>
        <cmdp:identifier>http://urn.fi/urn:nbn:fi:lb-1</cmdp:identifier>
      </cmdp:identificationInfo>
      <cmdp:distributionInfo>
        <cmdp:availability>available-unrestrictedUse</cmdp:availability>
        <cmdp:licenceInfo>
          <cmdp:licence>CC-BY</cmdp:licence>
          <cmdp:distributionRightsHolderOrganization>
            <cmdp:role>distributionRightsHolder</cmdp:role>
            <cmdp:organizationInfo>
              <cmdp:organizationName xml:lang="en">University of Helsinki</cmdp:organizationName>
            </cmdp:organizationInfo>
          </cmdp:distributionRightsHolderOrganization>
        </cmdp:licenceInfo>
        <cmdp:iprHolderOrganization>
          <cmdp:role>iprHolder</cmdp:role>
        </cmdp:iprHolderOrganization>
      </cmdp:distributionInfo>
    </cmdp:resourceInfo>
  </cmd:Components>
</cmd:CMD>
""".encode()


def _record_12_with_licence(licence_value, availability="underNegotiation"):
    return f"""<?xml version='1.0' encoding='UTF-8'?>
<cmd:CMD xmlns:cmd="{CMD_NS}"
         xmlns:cmdp="{OLD_PROFILE_NS}"
         CMDVersion="1.2">
  <cmd:Header><cmd:MdProfile>{OLD_PROFILE}</cmd:MdProfile></cmd:Header>
  <cmd:Resources><cmd:ResourceProxyList/></cmd:Resources>
  <cmd:Components>
    <cmdp:resourceInfo>
      <cmdp:identificationInfo>
        <cmdp:resourceName xml:lang="en">Test</cmdp:resourceName>
        <cmdp:description xml:lang="en">Test.</cmdp:description>
      </cmdp:identificationInfo>
      <cmdp:distributionInfo>
        <cmdp:availability>{availability}</cmdp:availability>
        <cmdp:licenceInfo>
          <cmdp:licence>{licence_value}</cmdp:licence>
        </cmdp:licenceInfo>
      </cmdp:distributionInfo>
    </cmdp:resourceInfo>
  </cmd:Components>
</cmd:CMD>
""".encode()


def _convert_and_parse(record=None):
    return etree.fromstring(convert(record or _MINIMAL_RECORD_12))


def _new_ns(tag):
    return f"{{{NEW_PROFILE_NS}}}{tag}"


def _cmd_ns(tag):
    return f"{{{CMD_NS}}}{tag}"


class TestCmdi12ProfileUpdate:
    """The profile ID and schemaLocation are rewritten."""

    def test_mdprofile_updated(self):
        """MdProfile element should contain the new profile ID."""
        root = _convert_and_parse()
        profile = root.find(f".//{_cmd_ns('MdProfile')}")
        assert profile.text == NEW_PROFILE

    def test_schemalocation_updated(self):
        """xsi:schemaLocation should reference the new profile, not the old."""
        root = _convert_and_parse()
        xsi_ns = "http://www.w3.org/2001/XMLSchema-instance"
        loc = root.get(f"{{{xsi_ns}}}schemaLocation")
        assert NEW_PROFILE_NS in loc
        assert OLD_PROFILE_NS not in loc


class TestCmdi12Renaming:
    """Profile element namespace and root component name changes."""

    def test_profile_elements_in_new_namespace(self):
        """All profile elements should be in the new profile namespace."""
        root = _convert_and_parse()
        # Every element under Components should be in the new namespace.
        components = root.find(_cmd_ns("Components"))
        for el in components.iter():
            if el is components:
                continue
            assert (
                el.nsmap.get(el.prefix) != OLD_PROFILE_NS
            ), f"{el.tag} still in old profile namespace"

    def test_root_component_renamed(self):
        """resourceInfo should become resourceInfo-corpus-v1."""
        root = _convert_and_parse()
        components = root.find(_cmd_ns("Components"))
        assert components[0].tag == _new_ns("resourceInfo-corpus-v1")

    def test_old_root_component_absent(self):
        """resourceInfo in either the old or new namespace should not appear."""
        root = _convert_and_parse()
        for ns in (OLD_PROFILE_NS, NEW_PROFILE_NS):
            assert root.find(f".//{{{ns}}}resourceInfo") is None


class TestCmdi12IdentificationInfo:
    """identificationInfo is restructured."""

    def test_resourcename_kept(self):
        root = _convert_and_parse()
        el = root.find(f".//{_new_ns('resourceName')}")
        assert el is not None and el.text == "Test Corpus"

    def test_resourceshortname_kept(self):
        root = _convert_and_parse()
        el = root.find(f".//{_new_ns('resourceShortName')}")
        assert el is not None and el.text == "test-corpus"

    def test_metashareid_dropped(self):
        root = _convert_and_parse()
        assert root.find(f".//{_new_ns('metaShareId')}") is None

    def test_identifier_dropped(self):
        root = _convert_and_parse()
        assert root.find(f".//{_new_ns('identifier')}") is None


class TestCmdi12DistributionInfo:
    """distributionInfo is restructured."""

    def test_access_info_added(self):
        root = _convert_and_parse()
        assert root.find(f".//{_new_ns('accessInfo')}") is not None

    def test_licence_info_renamed(self):
        root = _convert_and_parse()
        assert root.find(f".//{_new_ns('licenceInfo')}") is None
        assert root.find(f".//{_new_ns('licenseInfo')}") is not None

    def test_ipr_holder_dropped(self):
        root = _convert_and_parse()
        assert root.find(f".//{_new_ns('iprHolderOrganization')}") is None

    def test_rights_holder_organisation_kept(self):
        license_info = _convert_and_parse().find(f".//{_new_ns('licenseInfo')}")
        assert (
            license_info.find(_new_ns("distributionRightsHolderOrganization"))
            is not None
        )


class TestCmdi12AvailabilityMapping:
    """availability enum values are mapped to the new set."""

    def _availability(self, value):
        root = _convert_and_parse(_record_12_with_licence("CC-BY", value))
        return root.find(f".//{_new_ns('availability')}").text

    def test_available_unrestricted(self):
        assert self._availability("available-unrestrictedUse") == "Available"

    def test_available_restricted(self):
        assert self._availability("available-restrictedUse") == "Available"

    def test_not_available(self):
        assert self._availability("notAvailableThroughMetaShare") == "Archived"

    def test_under_negotiation(self):
        assert self._availability("underNegotiation") == "Preliminary"


class TestCmdi12LicenceMapping:
    """licence -> licenseType mapping."""

    def _license_type(self, value):
        root = _convert_and_parse(_record_12_with_licence(value))
        return root.find(f".//{_new_ns('licenseType')}").text

    def test_cc_by(self):
        assert self._license_type("CC-BY") == "CC BY"

    def test_clarin_aca(self):
        assert self._license_type("CLARIN_ACA") == "CLARIN ACA +ID +BY +NORED"

    def test_unknown_gets_prefix(self):
        assert self._license_type("underNegotiation") == ":: underNegotiation"

    def test_known_licence_gets_license_link(self):
        root = _convert_and_parse(_record_12_with_licence("CC-BY"))
        url = root.find(
            f".//{_new_ns('licenseLink')}/{_new_ns('link')}/{_new_ns('url')}"
        )
        assert url is not None and "creativecommons.org" in url.text

    def test_unknown_licence_has_no_license_link(self):
        root = _convert_and_parse(_record_12_with_licence("underNegotiation"))
        assert root.find(f".//{_new_ns('licenseLink')}") is None


class TestCmdi12VersionDetection:
    """The correct stylesheet is selected based on CMDVersion."""

    def test_cmdi11_record_still_converts(self):
        """A CMDI 1.1 record routes to the correct stylesheet and produces CMDI 1.2."""
        from tests.test_convert_cmdi11 import _MINIMAL_RECORD  # noqa: PLC0415

        root = etree.fromstring(convert(_MINIMAL_RECORD))
        # Root should be in the CMDI 1.2 envelope namespace
        assert root.tag == _cmd_ns("CMD")
        # Profile content should be in the new profile namespace
        components = root.find(_cmd_ns("Components"))
        assert components[0].tag == _new_ns("resourceInfo-corpus-v1")

    def test_cmdi12_record_converts(self):
        """A CMDI 1.2 record produces output with profile elements in the new namespace."""
        root = _convert_and_parse()
        components = root.find(_cmd_ns("Components"))
        assert components[0].tag == _new_ns("resourceInfo-corpus-v1")
