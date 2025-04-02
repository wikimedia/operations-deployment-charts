{{- define "configmap.wikimediwi-dumps-legacy-configs" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: mediwiki-dumps-legacy-configs
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  wikidump.conf.dumps: |
{{ .Files.Get "files/config/wikidump.conf.dumps" | indent 4 }}
  wikidump.conf.tests: |
{{ .Files.Get "files/config/wikidump.conf.tests" | indent 4 }}
  wikidump.conf.other: |
{{ .Files.Get "files/config/wikidump.conf.other" | indent 4 }}
  table_jobs.yaml: |
{{ .Files.Get "files/config/table_jobs.yaml" | indent 4 }}
{{ end }}

{{- define "configmap.wikimediwi-dumps-legacy-templates" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: mediwiki-dumps-legacy-templates
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  download-index.html: |
{{ .Files.Get "files/templates/download-index.html" | indent 4 }}
  errormail.txt: |
{{ .Files.Get "files/templates/errormail.txt" | indent 4 }}
  feed.xml: |
{{ .Files.Get "files/templates/feed.xml" | indent 4 }}
  incrs-index.html: |
{{ .Files.Get "files/templates/incrs-index.html" | indent 4 }}
  report.html: |
{{ .Files.Get "files/templates/report.html" | indent 4 }}
{{ end }}

{{- define "configmap.wikimediwi-dumps-legacy-dblists" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: mediwiki-dumps-legacy-dblists
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  bigwikis.dblist: |
    arwiki
    dewiki
    commonswiki
    frwiki
    eswiki
    hewiki
    huwiki
    itwiki
    jawiki
    kowiki
    metawiki
    nlwiki
    plwiki
    ptwiki
    ruwiki
    svwiki
    ukwiki
    viwiki
    zhwiki
  enwiki.dblist: |
    enwiki
  wikidatawiki.dblist: |
    wikidatawiki
  skip.dblist: |
    enwiki
    wikidatawiki
    arwiki
    dewiki
    commonswiki
    frwiki
    eswiki
    hewiki
    huwiki
    itwiki
    jawiki
    kowiki
    metawiki
    nlwiki
    plwiki
    ptwiki
    ruwiki
    svwiki
    ukwiki
    viwiki
    zhwiki
  skipnone.dblist: |
    # empty file
{{ end }}

