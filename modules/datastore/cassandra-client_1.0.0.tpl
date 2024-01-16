{{/*
Generic Cassandra configuration interface

This module implments a fairly generic configuration definition for
connecting to Cassandra on WMF infrastructure, based on the format
used by AQS2 services.

Creates the following objects:
- a templated configuration definition
- a ConfigMap containing the same definition
- a Volume containing the configmap
- a networkpolicy egress definition for all configured hosts

Any or all of the above can be used depending on the requirements of the application
*/}}

{{/*
Volume mounting the configmap
*/}}
{{ define "datastore.cassandra_client.volume" }}
{{- if .Values.datastore.cassandra_client.enabled }}
# Cassandra configuration
- name: {{ template "base.name.release" . }}-cassandra_client
  configMap:
    name: {{ template "base.name.release" . }}-cassandra_client-config
{{- end }}
{{- end }}

{{/*
Definition of cassandra config
*/}}
{{ define "datastore.cassandra_client.config" }}
{{- with .Values.datastore.cassandra_client -}}
cassandra:
  port: {{ .port }}
  consistency: {{ .consistency }}
  hosts:
{{- range $cassandra_host := .hosts }}
    - {{ $cassandra_host }}
{{- end }}
  local_dc: {{ .local_dc }}
  authentication:
    username: {{ .authentication.username }}
    password: {{ .authentication.password }}
  tls:
    ca: {{ .tls.ca }}
{{- end -}}
{{- end -}}

{{/*
Configmap containing the defined config
*/}}
{{- define "datastore.cassandra_client.configmap" -}}
{{- if .Values.datastore.cassandra_client.enabled }}
---
apiVersion: v1
kind: ConfigMap
metadata:
{{- include "base.meta.metadata" (dict "Root" . "Name" "cassandra_client-config" ) | indent 2 }}
data:
  config.json: |-
{{ include "datastore.cassandra_client.config" . | indent 4 }}
{{- end }}
{{- end }}

{{/* Networkpolicy egress - simply create one egress entry per defined host */}}
{{- define "datastore.cassandra_client.egress" -}}
{{- if .Values.datastore.cassandra_client.enabled }}
{{- range .Values.datastore.cassandra_client.hosts }}
- cidr: {{ . }}/32
  ports:
  - protocol: TCP
    port: {{ $.Values.datastore.cassandra_client.port }}
{{- end }}
{{- end -}}
{{- end -}}
