<?xml version="1.0" encoding="UTF-8"?>
<!--
  CMDI 1.1 -> CMDI 1.2 conversion: resourceInfo -> resourceInfo-corpus-v1.

  CMDI 1.1 uses a single namespace for both envelope and profile elements
  (http://www.clarin.eu/cmd/).  This stylesheet outputs CMDI 1.2:
    - Envelope elements (CMD, Header, Resources, Components, ...) in
      http://www.clarin.eu/cmd/1
    - Profile elements (everything inside Components) in
      http://www.clarin.eu/cmd/1/profiles/clarin.eu:cr1:p_1778593302234
    - CMDVersion="1.2" set on the root element
    - ComponentId attributes dropped (CMDI 1.2 uses namespace-based identity)
  The structural conversion rules (resourceInfo rename, identificationInfo and
  distributionInfo restructure, availability and licence mapping) are the same
  as in the 1.2 stylesheet.
-->
<xsl:stylesheet
    version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:cmd11="http://www.clarin.eu/cmd/"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:str="http://exslt.org/strings"
    exclude-result-prefixes="xsl cmd11 str">

  <xsl:variable name="ENVELOPE_NS" select="'http://www.clarin.eu/cmd/1'"/>
  <xsl:variable name="NEW_PROFILE_NS"
    select="'http://www.clarin.eu/cmd/1/profiles/clarin.eu:cr1:p_1778593302234'"/>

  <!-- ============================================================
       GENERAL RULES
       ============================================================ -->

  <!-- Pass text, comments, and processing instructions through unchanged -->
  <xsl:template match="text()|comment()|processing-instruction()">
    <xsl:copy/>
  </xsl:template>

  <!-- Pass all attributes through unchanged (specific templates override below) -->
  <xsl:template match="@*">
    <xsl:copy/>
  </xsl:template>

  <!-- Drop ComponentId attributes: component identity in CMDI 1.2 is namespace-based -->
  <xsl:template match="@ComponentId"/>

  <!-- Drop CMDVersion: set explicitly on the root element -->
  <xsl:template match="@CMDVersion"/>

  <!-- Root element: re-namespace to CMDI 1.2 envelope, set CMDVersion="1.2".
       IsPartOfList is a direct CMD child in CMDI 1.2, not inside Resources. -->
  <xsl:template match="cmd11:CMD">
    <xsl:element name="CMD" namespace="{$ENVELOPE_NS}">
      <xsl:attribute name="CMDVersion">1.2</xsl:attribute>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates select="cmd11:Header"/>
      <xsl:element name="Resources" namespace="{$ENVELOPE_NS}">
        <xsl:apply-templates select="cmd11:Resources/*[not(self::cmd11:IsPartOfList)]"/>
      </xsl:element>
      <xsl:apply-templates select="cmd11:Resources/cmd11:IsPartOfList"/>
      <xsl:apply-templates select="cmd11:Components"/>
    </xsl:element>
  </xsl:template>

  <!-- General: all CMDI 1.1 envelope elements -> CMDI 1.2 envelope namespace -->
  <xsl:template match="cmd11:*">
    <xsl:element name="{local-name()}" namespace="{$ENVELOPE_NS}">
      <xsl:apply-templates select="@*|node()"/>
    </xsl:element>
  </xsl:template>

  <!-- Update schemaLocation: CMDI 1.2 envelope schema + new profile XSD -->
  <xsl:template match="@xsi:schemaLocation">
    <xsl:attribute name="xsi:schemaLocation">
      <xsl:value-of select="concat(
        'http://www.clarin.eu/cmd/1 https://infra.clarin.eu/CMDI/1.x/xsd/cmd-envelop.xsd ',
        $NEW_PROFILE_NS, ' ',
        'https://catalog.clarin.eu/ds/ComponentRegistry/rest/registry/1.2/profiles/clarin.eu:cr1:p_1778593302234/xsd'
      )"/>
    </xsl:attribute>
  </xsl:template>

  <!-- Update profile ID in header -->
  <xsl:template match="cmd11:MdProfile">
    <xsl:element name="MdProfile" namespace="{$ENVELOPE_NS}">
      <xsl:text>clarin.eu:cr1:p_1778593302234</xsl:text>
    </xsl:element>
  </xsl:template>

  <!-- ============================================================
       PROFILE ELEMENTS (inside Components)
       ============================================================ -->

  <!-- General: re-namespace old profile elements to new profile NS -->
  <xsl:template match="cmd11:Components//*" priority="1">
    <xsl:element name="{local-name()}" namespace="{$NEW_PROFILE_NS}">
      <xsl:apply-templates select="@*|node()"/>
    </xsl:element>
  </xsl:template>

  <!-- Root component: explicit child ordering -->
  <xsl:template match="cmd11:resourceInfo" priority="2">
    <xsl:element name="resourceInfo-corpus-v1" namespace="{$NEW_PROFILE_NS}">
      <xsl:apply-templates select="cmd11:identificationInfo"/>
      <xsl:apply-templates select="cmd11:distributionInfo"/>
      <xsl:apply-templates select="cmd11:contactPerson"/>
      <xsl:apply-templates select="cmd11:metadataInfo"/>
      <xsl:apply-templates select="cmd11:versionInfo"/>
      <xsl:apply-templates select="cmd11:usageInfo"/>
      <xsl:apply-templates select="cmd11:resourceDocumentationInfo"/>
      <xsl:apply-templates select="cmd11:resourceCreationInfo"/>
      <!-- Merge multiple old relationInfo elements into one new-style relationInfo -->
      <xsl:if test="cmd11:relationInfo">
        <xsl:element name="relationInfo" namespace="{$NEW_PROFILE_NS}">
          <xsl:for-each select="cmd11:relationInfo">
            <xsl:element name="relation" namespace="{$NEW_PROFILE_NS}">
              <xsl:apply-templates select="cmd11:relationType"/>
              <xsl:variable name="url">
                <xsl:call-template name="extract-url">
                  <xsl:with-param name="text"
                    select="cmd11:relatedResource/cmd11:targetResourceNameURI"/>
                </xsl:call-template>
              </xsl:variable>
              <xsl:if test="$url != ''">
                <xsl:element name="relatedResourceLink" namespace="{$NEW_PROFILE_NS}">
                  <xsl:value-of select="$url"/>
                </xsl:element>
              </xsl:if>
            </xsl:element>
          </xsl:for-each>
        </xsl:element>
      </xsl:if>
      <!-- corpusInfo is required; generate a stub when absent -->
      <xsl:choose>
        <xsl:when test="cmd11:corpusInfo">
          <xsl:apply-templates select="cmd11:corpusInfo"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="stub-corpus-info"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:element>
  </xsl:template>

  <!-- identificationInfo: reorder children, drop metaShareId/identifier/url,
       strip xml:lang from resourceShortName (plain xs:string in new profile) -->
  <xsl:template match="cmd11:identificationInfo" priority="2">
    <xsl:element name="identificationInfo" namespace="{$NEW_PROFILE_NS}">
      <xsl:apply-templates select="cmd11:resourceName"/>
      <xsl:for-each select="cmd11:resourceShortName[1]">
        <xsl:element name="resourceShortName" namespace="{$NEW_PROFILE_NS}">
          <xsl:value-of select="."/>
        </xsl:element>
      </xsl:for-each>
      <xsl:apply-templates select="cmd11:description"/>
    </xsl:element>
  </xsl:template>

  <!-- distributionInfo: restructure children, add mandatory copyrightInfo -->
  <xsl:template match="cmd11:distributionInfo" priority="2">
    <xsl:element name="distributionInfo" namespace="{$NEW_PROFILE_NS}">
      <xsl:apply-templates select="cmd11:availability"/>
      <xsl:apply-templates select="cmd11:availabilityStartDate"/>
      <xsl:apply-templates select="cmd11:availabilityEndDate"/>
      <xsl:element name="accessInfo" namespace="{$NEW_PROFILE_NS}">
        <xsl:for-each select="cmd11:licenceInfo/cmd11:distributionAccessMedium">
          <xsl:element name="distributionAccessMedium" namespace="{$NEW_PROFILE_NS}">
            <xsl:call-template name="map-access-medium">
              <xsl:with-param name="val" select="."/>
            </xsl:call-template>
          </xsl:element>
        </xsl:for-each>
      </xsl:element>
      <xsl:choose>
        <xsl:when test="count(cmd11:licenceInfo) &gt; 1">
          <xsl:element name="licenseInfo" namespace="{$NEW_PROFILE_NS}">
            <xsl:element name="licenseType" namespace="{$NEW_PROFILE_NS}">TODO: multiple licenceInfo, resolve manually</xsl:element>
          </xsl:element>
        </xsl:when>
        <xsl:when test="cmd11:licenceInfo">
          <xsl:apply-templates select="cmd11:licenceInfo"/>
        </xsl:when>
      </xsl:choose>
      <xsl:element name="copyrightInfo" namespace="{$NEW_PROFILE_NS}">
        <xsl:element name="copyrightStatus" namespace="{$NEW_PROFILE_NS}">unknown</xsl:element>
        <xsl:element name="description" namespace="{$NEW_PROFILE_NS}">
          <xsl:attribute name="xml:lang">en</xsl:attribute>
          <xsl:text>Copyright status not specified in original record.</xsl:text>
        </xsl:element>
      </xsl:element>
      <xsl:apply-templates select="cmd11:iprHolder"/>
      <xsl:apply-templates select="cmd11:iprHolderOrganization"/>
    </xsl:element>
  </xsl:template>

  <!-- Map old availability enum to new enum -->
  <xsl:template match="cmd11:distributionInfo/cmd11:availability" priority="2">
    <xsl:element name="availability" namespace="{$NEW_PROFILE_NS}">
      <xsl:choose>
        <xsl:when test=". = 'available-unrestrictedUse'">Available</xsl:when>
        <xsl:when test=". = 'available-restrictedUse'">Available</xsl:when>
        <xsl:when test=". = 'notAvailableThroughMetaShare'">Archived</xsl:when>
        <xsl:when test=". = 'underNegotiation'">Preliminary</xsl:when>
        <xsl:otherwise><xsl:value-of select="."/></xsl:otherwise>
      </xsl:choose>
    </xsl:element>
  </xsl:template>

  <!-- licenceInfo -> licenseInfo: remap licence values, migrate rights holders -->
  <xsl:template match="cmd11:licenceInfo" priority="2">
    <xsl:element name="licenseInfo" namespace="{$NEW_PROFILE_NS}">
      <xsl:for-each select="cmd11:licence">
        <xsl:element name="licenseType" namespace="{$NEW_PROFILE_NS}">
          <xsl:call-template name="map-licence">
            <xsl:with-param name="val" select="."/>
          </xsl:call-template>
        </xsl:element>
      </xsl:for-each>
      <xsl:for-each select="cmd11:licence">
        <xsl:variable name="url">
          <xsl:call-template name="licence-url">
            <xsl:with-param name="val" select="."/>
          </xsl:call-template>
        </xsl:variable>
        <xsl:if test="$url != ''">
          <xsl:element name="licenseLink" namespace="{$NEW_PROFILE_NS}">
            <xsl:element name="link" namespace="{$NEW_PROFILE_NS}">
              <xsl:element name="url" namespace="{$NEW_PROFILE_NS}">
                <xsl:value-of select="$url"/>
              </xsl:element>
            </xsl:element>
          </xsl:element>
        </xsl:if>
      </xsl:for-each>
      <xsl:apply-templates select="cmd11:licensorPerson"/>
      <xsl:apply-templates select="cmd11:licensorOrganization"/>
      <xsl:apply-templates select="cmd11:distributionRightsHolderPerson"/>
      <xsl:apply-templates select="cmd11:distributionRightsHolderOrganization"/>
    </xsl:element>
  </xsl:template>

  <!-- metadataInfo: drop fields no longer present in the new profile, add
  metadataRevisionLog (from revision) and metadataRecordInfo (from
  MdSelfLink); migrate metadataCreator -->
  <xsl:template match="cmd11:metadataInfo" priority="2">
    <xsl:element name="metadataInfo" namespace="{$NEW_PROFILE_NS}">
      <xsl:apply-templates select="cmd11:metadataCreationDate"/>
      <xsl:apply-templates select="cmd11:metadataLastDateUpdated"/>
      <xsl:element name="metadataRevisionLog" namespace="{$NEW_PROFILE_NS}">
        <xsl:variable name="rev-date">
          <xsl:choose>
            <xsl:when test="string(cmd11:metadataLastDateUpdated)">
              <xsl:value-of select="cmd11:metadataLastDateUpdated"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="cmd11:metadataCreationDate"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:for-each select="cmd11:revision[string($rev-date)]">
          <xsl:element name="logEntry" namespace="{$NEW_PROFILE_NS}">
            <xsl:element name="date" namespace="{$NEW_PROFILE_NS}">
              <xsl:value-of select="$rev-date"/>
            </xsl:element>
            <xsl:element name="note" namespace="{$NEW_PROFILE_NS}">
              <xsl:attribute name="xml:lang">en</xsl:attribute>
              <xsl:value-of select="."/>
            </xsl:element>
          </xsl:element>
        </xsl:for-each>
      </xsl:element>
      <xsl:variable name="selflink"
        select="ancestor::cmd11:CMD/cmd11:Header/cmd11:MdSelfLink"/>
      <xsl:element name="metadataRecordInfo" namespace="{$NEW_PROFILE_NS}">
        <xsl:element name="MetadataRecordIdentifier" namespace="{$NEW_PROFILE_NS}">
          <xsl:attribute name="MetadataRecordIdentifierScheme">urn</xsl:attribute>
          <xsl:value-of select="$selflink"/>
        </xsl:element>
      </xsl:element>
      <xsl:choose>
        <xsl:when test="count(cmd11:metadataCreator) &gt; 1">
          <xsl:element name="metadataCreator" namespace="{$NEW_PROFILE_NS}">
            <xsl:element name="personInfo" namespace="{$NEW_PROFILE_NS}">
              <xsl:element name="surname" namespace="{$NEW_PROFILE_NS}">TODO: multiple metadataCreator, resolve manually</xsl:element>
            </xsl:element>
          </xsl:element>
        </xsl:when>
        <xsl:when test="cmd11:metadataCreator">
          <xsl:apply-templates select="cmd11:metadataCreator"/>
        </xsl:when>
      </xsl:choose>
    </xsl:element>
  </xsl:template>

  <!-- metadataCreator: select relevant personInfo fields -->
  <xsl:template match="cmd11:metadataCreator" priority="3">
    <xsl:element name="metadataCreator" namespace="{$NEW_PROFILE_NS}">
      <xsl:element name="personInfo" namespace="{$NEW_PROFILE_NS}">
        <xsl:apply-templates select="cmd11:personInfo/cmd11:surname"/>
        <xsl:apply-templates select="cmd11:personInfo/cmd11:givenName"/>
        <xsl:apply-templates select="cmd11:personInfo/cmd11:communicationInfo/cmd11:email"/>
      </xsl:element>
    </xsl:element>
  </xsl:template>

  <!-- resourceCreationInfo: add todos where required fields cannot be filled properly -->
  <xsl:template match="cmd11:resourceCreationInfo" priority="2">
    <xsl:element name="resourceCreationInfo" namespace="{$NEW_PROFILE_NS}">
      <xsl:apply-templates select="cmd11:creationStartDate"/>
      <xsl:apply-templates select="cmd11:creationEndDate"/>
      <xsl:choose>
        <xsl:when test="count(cmd11:resourceCreatorPerson) &gt; 1">
          <xsl:element name="resourceCreatorPerson" namespace="{$NEW_PROFILE_NS}">
            <xsl:element name="role" namespace="{$NEW_PROFILE_NS}">resourceCreator</xsl:element>
            <xsl:element name="personInfo" namespace="{$NEW_PROFILE_NS}">
              <xsl:element name="surname" namespace="{$NEW_PROFILE_NS}">TODO: multiple resourceCreatorPerson, resolve manually</xsl:element>
            </xsl:element>
          </xsl:element>
        </xsl:when>
        <xsl:when test="cmd11:resourceCreatorPerson">
          <xsl:apply-templates select="cmd11:resourceCreatorPerson"/>
        </xsl:when>
      </xsl:choose>
      <xsl:choose>
        <xsl:when test="count(cmd11:resourceCreatorOrganization) &gt; 1">
          <xsl:element name="resourceCreatorOrganization" namespace="{$NEW_PROFILE_NS}">
            <xsl:element name="role" namespace="{$NEW_PROFILE_NS}">resourceCreator</xsl:element>
            <xsl:element name="organizationInfo" namespace="{$NEW_PROFILE_NS}">
              <xsl:element name="organizationName" namespace="{$NEW_PROFILE_NS}">TODO: multiple resourceCreatorOrganization, resolve manually</xsl:element>
            </xsl:element>
          </xsl:element>
        </xsl:when>
        <xsl:when test="cmd11:resourceCreatorOrganization">
          <xsl:apply-templates select="cmd11:resourceCreatorOrganization"/>
        </xsl:when>
      </xsl:choose>
      <xsl:apply-templates select="cmd11:fundingProject"/>
      <xsl:element name="resourceRevisionLog" namespace="{$NEW_PROFILE_NS}"/>
    </xsl:element>
  </xsl:template>

  <!-- iprHolder/iprHolderOrganization -> rightholderPerson/rightholderOrganization -->
  <xsl:template match="cmd11:iprHolder" priority="2">
    <xsl:element name="rightholderPerson" namespace="{$NEW_PROFILE_NS}">
      <xsl:element name="role" namespace="{$NEW_PROFILE_NS}">rightholder</xsl:element>
      <xsl:apply-templates select="cmd11:personInfo"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="cmd11:iprHolderOrganization" priority="2">
    <xsl:element name="rightholderOrganization" namespace="{$NEW_PROFILE_NS}">
      <xsl:element name="role" namespace="{$NEW_PROFILE_NS}">rightHolder</xsl:element>
      <xsl:apply-templates select="cmd11:organizationInfo"/>
    </xsl:element>
  </xsl:template>

  <!-- Force role first; limit info to [1] (source may have multiple or wrong order) -->
  <xsl:template match="cmd11:resourceCreatorOrganization|cmd11:distributionRightsHolderOrganization|
                       cmd11:licensorOrganization|cmd11:rightholderOrganization|
                       cmd11:resourceCreatorPerson|cmd11:distributionRightsHolderPerson|
                       cmd11:licensorPerson|cmd11:rightholderPerson|
                       cmd11:contactPerson|cmd11:metadataCreator|
                       cmd11:affiliation" priority="2">
    <xsl:element name="{local-name()}" namespace="{$NEW_PROFILE_NS}">
      <xsl:apply-templates select="cmd11:role"/>
      <xsl:apply-templates select="*[local-name() != 'role'][1]"/>
    </xsl:element>
  </xsl:template>

  <!-- Documentation containers: role first; add stub role when absent from source;
       suppress entirely when the info child has no content (source data quality) -->
  <xsl:template match="cmd11:documentationStructured|cmd11:documentationUnstructured|
                       cmd11:documentationStructuredWithUrl" priority="2">
    <xsl:variable name="info" select="*[local-name() != 'role'][1]"/>
    <xsl:if test="$info/* or $info/text()[normalize-space()]">
      <xsl:element name="{local-name()}" namespace="{$NEW_PROFILE_NS}">
        <xsl:choose>
          <xsl:when test="cmd11:role">
            <xsl:apply-templates select="cmd11:role"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:element name="role" namespace="{$NEW_PROFILE_NS}">documentation</xsl:element>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:apply-templates select="$info"/>
      </xsl:element>
    </xsl:if>
  </xsl:template>

  <!-- Normalize non-standard Res1/Res2 resource proxy types to Resource -->
  <xsl:template match="cmd11:Res1|cmd11:Res2">
    <xsl:element name="Resource" namespace="{$ENVELOPE_NS}">
      <xsl:apply-templates select="@*|node()"/>
    </xsl:element>
  </xsl:template>

  <xsl:template name="stub-corpus-info">
    <xsl:element name="corpusInfo" namespace="{$NEW_PROFILE_NS}">
      <xsl:element name="resourceType" namespace="{$NEW_PROFILE_NS}">corpus</xsl:element>
      <xsl:element name="corpusMediaType" namespace="{$NEW_PROFILE_NS}"/>
    </xsl:element>
  </xsl:template>

  <!-- ============================================================
       HELPER TEMPLATES
       ============================================================ -->

  <!-- Extract the URL from a targetResourceNameURI value that may contain
       both free-text and a URL (e.g. "Some Label https://example.com").
       Tokenizes on whitespace (spaces, tabs, newlines) and picks the first token
       starting with http(s)://. Returns empty string when no URL token is found. -->
  <xsl:template name="extract-url">
    <xsl:param name="text"/>
    <xsl:variable name="url"
      select="str:tokenize($text, ' &#9;&#10;')[starts-with(., 'https://') or starts-with(., 'http://')]"/>
    <xsl:if test="$url">
      <xsl:value-of select="$url[1]"/>
    </xsl:if>
  </xsl:template>

  <!-- ============================================================
       RELATION TYPE MAPPING
       ============================================================ -->

  <!-- Map old relationType free-text to new closed enum -->
  <xsl:template match="cmd11:relationType" priority="2">
    <xsl:element name="relationType" namespace="{$NEW_PROFILE_NS}">
      <xsl:choose>
        <xsl:when test=". = 'IsVariantFormOf'">IsVariantFormOf</xsl:when>
        <xsl:when test=". = 'IsOriginalFormOf'">IsOriginalFormOf</xsl:when>
        <xsl:when test=". = 'IsDerivedFrom'">IsDerivedFrom</xsl:when>
        <xsl:when test=". = 'IsSourceOf'">IsSourceOf</xsl:when>
        <xsl:when test=". = 'IsPreviousVersionOf'">IsPreviousVersionOf</xsl:when>
        <xsl:when test=". = 'IsNewVersionOf'">IsNewVersionOf</xsl:when>
        <xsl:when test=". = 'IsPartOf'">IsPartOf</xsl:when>
        <xsl:when test=". = 'HasPart'">HasPart</xsl:when>
        <xsl:when test=". = 'IsContinuedBy'">IsContinuedBy</xsl:when>
        <xsl:when test=". = 'Continues'">Continues</xsl:when>
        <xsl:when test=". = 'IsCompiledBy'">IsCompiledBy</xsl:when>
        <xsl:when test=". = 'Compiles'">Compiles</xsl:when>
        <xsl:otherwise>Other</xsl:otherwise>
      </xsl:choose>
    </xsl:element>
  </xsl:template>

  <!-- ============================================================
       LICENCE MAPPING
       ============================================================ -->

  <xsl:template name="map-access-medium">
    <xsl:param name="val"/>
    <xsl:choose>
      <xsl:when test="$val = 'downloadable'">Downloadable</xsl:when>
      <xsl:when test="$val = 'accessibleThroughInterface'">Web Interface</xsl:when>
      <xsl:when test="$val = 'webExecutable'">Downloadable</xsl:when>  <!-- This is only present in https://clarino.uib.no/comedi/editor/lb-2019082801 and that is in fact downloadable from zenodo -->
      <xsl:otherwise>Other</xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="map-licence">
    <xsl:param name="val"/>
    <xsl:choose>
      <xsl:when test="$val = 'CC-BY'">CC BY</xsl:when>
      <xsl:when test="$val = 'CC-BY-NC'">CC BY-NC</xsl:when>
      <xsl:when test="$val = 'CC-BY-NC-ND'">CC BY-NC-ND</xsl:when>
      <xsl:when test="$val = 'CC-BY-NC-SA'">CC BY-NC-SA</xsl:when>
      <xsl:when test="$val = 'CC-BY-ND'">CC BY-ND</xsl:when>
      <xsl:when test="$val = 'CC-BY-SA'">CC BY-SA</xsl:when>
      <xsl:when test="$val = 'CC-ZERO'">CC0</xsl:when>
      <xsl:when test="$val = 'CLARIN_PUB'">TODO: ambiguous value CLARIN_PUB in original</xsl:when>
      <xsl:when test="$val = 'CLARIN_ACA'">TODO: ambiguous value CLARIN_ACA in original</xsl:when>
      <xsl:when test="$val = 'CLARIN_ACA-NC'">TODO: ambiguous value CLARIN_ACA-NC in original</xsl:when>
      <xsl:when test="$val = 'CLARIN_RES'">TODO: ambiguous value CLARIN_RES in original</xsl:when>
      <xsl:when test="$val = 'AGPL'">AGPL</xsl:when>
      <xsl:when test="$val = 'GPL'">GPL</xsl:when>
      <xsl:when test="$val = 'LGPL'">LGPL</xsl:when>
      <xsl:when test="$val = 'MIT'">MIT</xsl:when>
      <xsl:otherwise>:: <xsl:value-of select="$val"/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="licence-url">
    <xsl:param name="val"/>
    <xsl:choose>
      <xsl:when test="$val = 'CC-BY'">https://creativecommons.org/licenses/by/4.0/</xsl:when>
      <xsl:when test="$val = 'CC-BY-NC'">https://creativecommons.org/licenses/by-nc/4.0/</xsl:when>
      <xsl:when test="$val = 'CC-BY-NC-ND'">https://creativecommons.org/licenses/by-nc-nd/4.0/</xsl:when>
      <xsl:when test="$val = 'CC-BY-NC-SA'">https://creativecommons.org/licenses/by-nc-sa/4.0/</xsl:when>
      <xsl:when test="$val = 'CC-BY-ND'">https://creativecommons.org/licenses/by-nd/4.0/</xsl:when>
      <xsl:when test="$val = 'CC-BY-SA'">https://creativecommons.org/licenses/by-sa/4.0/</xsl:when>
      <xsl:when test="$val = 'CC-ZERO'">https://creativecommons.org/publicdomain/zero/1.0/</xsl:when>
      <xsl:when test="$val = 'CLARIN_PUB'">TODO: unknown license url</xsl:when>
      <xsl:when test="$val = 'CLARIN_ACA'">TODO: unknown license url</xsl:when>
      <xsl:when test="$val = 'CLARIN_ACA-NC'">TODO: unknown license url</xsl:when>
      <xsl:when test="$val = 'CLARIN_RES'">TODO: unknown license url</xsl:when>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
