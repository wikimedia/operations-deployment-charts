{{ define "imagemagick-policy.config" }}
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policymap [
  <!ELEMENT policymap (policy)+>
  <!ATTLIST policymap xmlns CDATA #FIXED ''>
  <!ELEMENT policy EMPTY>
  <!ATTLIST policy xmlns CDATA #FIXED '' domain NMTOKEN #REQUIRED
    name NMTOKEN #IMPLIED pattern CDATA #IMPLIED rights NMTOKEN #IMPLIED
    stealth NMTOKEN #IMPLIED value CDATA #IMPLIED>
]>
<!--
  Configure ImageMagick policies.

  Domains include system, delegate, coder, filter, path, or resource.

  Rights include none, read, write, execute and all.  Use | to combine them,
  for example: "read | write" to permit read from, or write to, a path.

  Use a glob expression as a pattern.

  Suppose we do not want users to process MPEG video images:

    <policy domain="delegate" rights="none" pattern="mpeg:decode" />

  Here we do not want users reading images from HTTP:

    <policy domain="coder" rights="none" pattern="HTTP" />

  The /repository file system is restricted to read only.  We use a glob
  expression to match all paths that start with /repository:

    <policy domain="path" rights="read" pattern="/repository/*" />

  Lets prevent users from executing any image filters:

    <policy domain="filter" rights="none" pattern="*" />

  Any large image is cached to disk rather than memory:

    <policy domain="resource" name="area" value="1GP"/>

  Define arguments for the memory, map, area, width, height and disk resources
  with SI prefixes (.e.g 100MB).  In addition, resource policies are maximums
  for each instance of ImageMagick (e.g. policy memory limit 1GB, -limit 2GB
  exceeds policy maximum so memory limit is 1GB).

  Rules are processed in order.  Here we want to restrict ImageMagick to only
  read or write a small subset of proven web-safe image types:

    <policy domain="delegate" rights="none" pattern="*" />
    <policy domain="filter" rights="none" pattern="*" />
    <policy domain="coder" rights="none" pattern="*" />
    <policy domain="coder" rights="read|write" pattern="{GIF,JPEG,PNG,WEBP}" />
-->
<policymap>
  <!-- <policy domain="system" name="shred" value="2"/> -->
  <!-- <policy domain="system" name="precision" value="6"/> -->
  <!-- <policy domain="system" name="memory-map" value="anonymous"/> -->
  <!-- <policy domain="system" name="max-memory-request" value="256MiB"/> -->
  <policy domain="resource" name="temporary-path" value="/tmp"/>
  <policy domain="resource" name="memory" value="{{ regexFind "\\d+" .Values.main_app.limits.memory  | int |  mulf 0.8 }}GiB"/>
  <policy domain="resource" name="disk" value="4GiB"/>
  <policy domain="resource" name="width" value="66KP"/>
  <policy domain="resource" name="height" value="66KP"/>
  <policy domain="resource" name="thread" value="4"/>
  <policy domain="resource" name="time" value="7200"/>
  <!-- <policy domain="resource" name="map" value="512MiB"/> -->
  <!-- <policy domain="resource" name="list-length" value="128"/> -->
  <!-- <policy domain="resource" name="area" value="128MB"/>  -->
  <!-- <policy domain="resource" name="file" value="768"/> -->
  <!-- <policy domain="resource" name="throttle" value="0"/> -->
  <!-- <policy domain="coder" rights="none" pattern="MVG" /> -->
  <!-- <policy domain="module" rights="none" pattern="{PS,PDF,XPS}" /> -->
  <!-- <policy domain="delegate" rights="none" pattern="HTTPS" /> -->
  <!-- <policy domain="path" rights="none" pattern="@*" /> -->
  <!-- <policy domain="cache" name="memory-map" value="anonymous"/> -->
  <!-- <policy domain="cache" name="synchronize" value="True"/> -->
  <!-- <policy domain="cache" name="shared-secret" value="passphrase" stealth="true"/> -->
  <!-- <policy domain="system" name="pixel-cache-memory" value="anonymous"/> -->
  <!-- <policy domain="system" name="shred" value="2"/> -->
  <!-- <policy domain="system" name="precision" value="6"/> -->
  <!-- not needed due to the need to use explicitly by mvg: -->
  <!-- <policy domain="delegate" rights="none" pattern="MVG" /> -->
  <!-- use curl -->
  <policy domain="delegate" rights="none" pattern="URL" />
  <policy domain="delegate" rights="none" pattern="HTTPS" />
  <policy domain="delegate" rights="none" pattern="HTTP" />
  <!-- in order to avoid to get image with password text -->
  <policy domain="path" rights="none" pattern="@*"/>
  <!-- disable ghostscript format types -->
  <policy domain="coder" rights="none" pattern="PS" />
  <policy domain="coder" rights="none" pattern="PS2" />
  <policy domain="coder" rights="none" pattern="PS3" />
  <policy domain="coder" rights="none" pattern="EPS" />
  <policy domain="coder" rights="none" pattern="PDF" />
  <policy domain="coder" rights="none" pattern="XPS" />
</policymap>
{{ end }}
