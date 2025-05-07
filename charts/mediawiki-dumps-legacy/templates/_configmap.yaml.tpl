{{- define "configmap.mediawiki-dumps-legacy-configs" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: mediwaiki-dumps-legacy-configs
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

{{- define "configmap.mediawiki-dumps-legacy-templates" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: mediawiki-dumps-legacy-templates
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

{{- define "configmap.mediawiki-dumps-legacy-dblists" }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: mediawiki-dumps-legacy-dblists
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

{{- define "configmap.mediawiki-dumps-legacy-ssh-known-hosts" }}
{{- if .Values.dumps.rsync.ssh_known_hosts }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: mediawiki-dumps-legacy-ssh-known-hosts
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  known_hosts: |
    {{- range .Values.dumps.rsync.ssh_known_hosts }}
    {{ . }}
    {{- end }}
{{ end }}
{{ end }}

{{- define "configmap.mediawiki-dumps-legacy-rsync-targets" }}
{{- if .Values.dumps.rsync.ssh_known_hosts }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: mediawiki-dumps-legacy-rsync-targets
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  rsync_targets: |
    {{- range .Values.dumps.rsync.ssh_known_hosts }}
    dumpsgen@{{ . | regexFind "[^,]*" }}
    {{- end }}
{{ end }}
{{ end }}

{{- define "configmap.mediawiki-dumps-legacy-ssh-config" }}
{{- if .Values.dumps.rsync.ssh_config }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: mediawiki-dumps-legacy-ssh-config
  {{- include "base.meta.labels" . | indent 2 }}
  namespace: {{ .Release.Namespace }}
data:
  config: |
    {{- if .Values.dumps.rsync.ssh_config.ciphers }}
    Ciphers {{ .Values.dumps.rsync.ssh_config.ciphers | join "," }}
    {{- end }}
{{ end }}
{{ end }}
