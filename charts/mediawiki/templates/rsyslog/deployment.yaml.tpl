{{ define "rsyslog.deployment" }}
{{ $release := include "wmf.releasename" . }}
{{- if .Values.mw.logging.rsyslog -}}
- name: {{ $release }}-rsyslog
  image: {{.Values.docker.registry }}/{{ .Values.common_images.rsyslogd }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  env:
    - name: KUBERNETES_NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
    - name: KUBERNETES_NODE
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
    - name: KUBERNETES_POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    - name: KUBERNETES_RELEASE
      valueFrom:
        fieldRef:
          fieldPath: metadata.labels.release
    - name: KUBERNETES_DEPLOYMENT
      valueFrom:
        fieldRef:
          fieldPath: metadata.labels.deployment

  resources:
    requests:
{{ toYaml .Values.mw.logging.requests | indent 6 }}
    limits:
{{ toYaml .Values.mw.logging.limits | indent 6 }}
  volumeMounts:
    # Mount the shared socket volume
  - name: {{ $release }}-rsyslog-config
    mountPath: /etc/rsyslog.d
{{- end }}
{{- end -}}
