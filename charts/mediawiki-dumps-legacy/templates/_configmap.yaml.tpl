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
{{ .Files.Get "config/wikidump.conf.dumps" | indent 4 }}
  wikidump.conf.other: |
{{ .Files.Get "config/wikidump.conf.other" | indent 4 }}
  table_jobs.yaml: |
{{ .Files.Get "config/table_jobs.yaml" | indent 4 }}
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

