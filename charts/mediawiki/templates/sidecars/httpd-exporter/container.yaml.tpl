{{define "sidecars.httpd-exporter.container"}}
{{ $release := include "base.name.release" . }}
{{- $flags := fromJson (include "mw.helpers.feature_flags" . ) -}}
# apache exporter on port 9117
- name: {{ $release }}-httpd-exporter
  image: {{ .Values.docker.registry }}/prometheus-apache-exporter:{{ .Values.php.httpd.exporter.version }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  args: ["--scrape_uri", "http://127.0.0.1:9181/server-status?auto"]
  ports:
    - name: httpd-metrics
      containerPort: 9117
  livenessProbe:
    tcpSocket:
      port: 9117
  resources:
    requests:
{{ toYaml .Values.php.httpd.exporter.requests | indent 6 }}
    limits:
{{ toYaml .Values.php.httpd.exporter.limits | indent 6 }}
{{- if .Values.main_app.prestop_sleep }}
{{ include "base.helper.prestop" .Values.main_app.prestop_sleep | nindent 2}}
{{- end }}
{{- include "base.helper.restrictedSecurityContext" . | indent 2 }}
{{- end }}