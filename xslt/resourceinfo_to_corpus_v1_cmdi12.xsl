<?xml version="1.0" encoding="UTF-8"?>
<!--
  CMDI 1.2 conversion: resourceInfo -> resourceInfo-corpus-v1.

  CMDI 1.2 encodes component identity via namespaces rather than ComponentId
  attributes.  Envelope elements (CMD, Header, Resources, Components) live in
  http://www.clarin.eu/cmd/1; profile elements live in a per-profile namespace
  http://www.clarin.eu/cmd/1/profiles/{profile-id}.  The conversion must
  re-namespace all old-profile elements into the new profile namespace, in
  addition to the same structural changes applied by the 1.1 stylesheet.
-->
<xsl:stylesheet
    version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:cmd="http://www.clarin.eu/cmd/1"
    xmlns:cmdp="http://www.clarin.eu/cmd/1/profiles/clarin.eu:cr1:p_1361876010571"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    exclude-result-prefixes="xsl cmdp">

  <xsl:variable name="OLD_NS"
    select="'http://www.clarin.eu/cmd/1/profiles/clarin.eu:cr1:p_1361876010571'"/>
  <xsl:variable name="NEW_NS"
    select="'http://www.clarin.eu/cmd/1/profiles/clarin.eu:cr1:p_1778593302234'"/>

  <!-- Identity transform -->
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <!-- General: re-namespace every old-profile element into the new profile NS -->
  <xsl:template match="*[namespace-uri() = 'http://www.clarin.eu/cmd/1/profiles/clarin.eu:cr1:p_1361876010571']">
    <xsl:element name="{local-name()}" namespace="{$NEW_NS}">
      <xsl:apply-templates select="@*|node()"/>
    </xsl:element>
  </xsl:template>

  <!-- Update schemaLocation to reference new profile -->
  <xsl:template match="@xsi:schemaLocation">
    <xsl:attribute name="xsi:schemaLocation">
      <xsl:value-of select="concat(
        'http://www.clarin.eu/cmd/1 https://infra.clarin.eu/CMDI/1.x/xsd/cmd-envelop.xsd ',
        $NEW_NS, ' ',
        'https://catalog.clarin.eu/ds/ComponentRegistry/rest/registry/1.2/profiles/clarin.eu:cr1:p_1778593302234/xsd'
      )"/>
    </xsl:attribute>
  </xsl:template>

  <!-- Update profile ID in header -->
  <xsl:template match="cmd:MdProfile">
    <cmd:MdProfile>clarin.eu:cr1:p_1778593302234</cmd:MdProfile>
  </xsl:template>

  <!-- Rename root component resourceInfo -> resourceInfo-corpus-v1 -->
  <xsl:template match="cmdp:resourceInfo" priority="1">
    <xsl:element name="resourceInfo-corpus-v1" namespace="{$NEW_NS}">
      <xsl:apply-templates select="@*|node()"/>
    </xsl:element>
  </xsl:template>

  <!-- identificationInfo: reorder children, drop metaShareId/identifier/url -->
  <xsl:template match="cmdp:identificationInfo" priority="1">
    <xsl:element name="identificationInfo" namespace="{$NEW_NS}">
      <xsl:apply-templates select="cmdp:resourceName"/>
      <xsl:apply-templates select="cmdp:resourceShortName"/>
      <xsl:apply-templates select="cmdp:description"/>
    </xsl:element>
  </xsl:template>

  <!-- distributionInfo: restructured children -->
  <xsl:template match="cmdp:distributionInfo" priority="1">
    <xsl:element name="distributionInfo" namespace="{$NEW_NS}">
      <xsl:apply-templates select="cmdp:availability"/>
      <xsl:apply-templates select="cmdp:availabilityStartDate"/>
      <xsl:apply-templates select="cmdp:availabilityEndDate"/>
      <xsl:element name="accessInfo" namespace="{$NEW_NS}"/>
      <xsl:apply-templates select="cmdp:licenceInfo"/>
      <!-- iprHolderOrganization/Person dropped: no equivalent in new profile -->
    </xsl:element>
  </xsl:template>

  <!-- Map old availability enum to new enum -->
  <xsl:template match="cmdp:distributionInfo/cmdp:availability" priority="1">
    <xsl:element name="availability" namespace="{$NEW_NS}">
      <xsl:choose>
        <xsl:when test=". = 'available-unrestrictedUse'">Available</xsl:when>
        <xsl:when test=". = 'available-restrictedUse'">Available</xsl:when>
        <xsl:when test=". = 'notAvailableThroughMetaShare'">Archived</xsl:when>
        <xsl:when test=". = 'underNegotiation'">Preliminary</xsl:when>
        <xsl:otherwise><xsl:value-of select="."/></xsl:otherwise>
      </xsl:choose>
    </xsl:element>
  </xsl:template>

  <!-- licenceInfo -> licenseInfo -->
  <xsl:template match="cmdp:licenceInfo" priority="1">
    <xsl:element name="licenseInfo" namespace="{$NEW_NS}">
      <xsl:for-each select="cmdp:licence">
        <xsl:element name="licenseType" namespace="{$NEW_NS}">
          <xsl:call-template name="map-licence">
            <xsl:with-param name="val" select="."/>
          </xsl:call-template>
        </xsl:element>
      </xsl:for-each>
      <xsl:for-each select="cmdp:licence">
        <xsl:variable name="url">
          <xsl:call-template name="licence-url">
            <xsl:with-param name="val" select="."/>
          </xsl:call-template>
        </xsl:variable>
        <xsl:if test="$url != ''">
          <xsl:element name="licenseLink" namespace="{$NEW_NS}">
            <xsl:element name="link" namespace="{$NEW_NS}">
              <xsl:element name="url" namespace="{$NEW_NS}">
                <xsl:value-of select="$url"/>
              </xsl:element>
            </xsl:element>
          </xsl:element>
        </xsl:if>
      </xsl:for-each>
      <xsl:apply-templates select="cmdp:distributionRightsHolderPerson"/>
      <xsl:apply-templates select="cmdp:distributionRightsHolderOrganization"/>
    </xsl:element>
  </xsl:template>

  <!-- Map old licence value to new licenseType string -->
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
      <xsl:when test="$val = 'CLARIN_PUB'">CLARIN PUB</xsl:when>
      <xsl:when test="$val = 'CLARIN_ACA'">CLARIN ACA +ID +BY +NORED</xsl:when>
      <xsl:when test="$val = 'CLARIN_ACA-NC'">CLARIN ACA +ID +BY +NC +NORED</xsl:when>
      <xsl:when test="$val = 'CLARIN_RES'">CLARIN RES +ID +PLAN +BY +NORED</xsl:when>
      <xsl:when test="$val = 'AGPL'">AGPL</xsl:when>
      <xsl:when test="$val = 'GPL'">GPL</xsl:when>
      <xsl:when test="$val = 'LGPL'">LGPL</xsl:when>
      <xsl:when test="$val = 'MIT'">MIT</xsl:when>
      <xsl:otherwise>:: <xsl:value-of select="$val"/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Canonical URL for known licence values -->
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
      <xsl:when test="$val = 'CLARIN_PUB'">https://www.kielipankki.fi/support/klarin-kayttolupasopimukset/</xsl:when>
      <xsl:when test="$val = 'CLARIN_ACA'">https://www.kielipankki.fi/support/klarin-kayttolupasopimukset/</xsl:when>
      <xsl:when test="$val = 'CLARIN_ACA-NC'">https://www.kielipankki.fi/support/klarin-kayttolupasopimukset/</xsl:when>
      <xsl:when test="$val = 'CLARIN_RES'">https://www.kielipankki.fi/support/klarin-kayttolupasopimukset/</xsl:when>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
