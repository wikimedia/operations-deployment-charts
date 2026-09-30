{{define "sidecars.php-fpm-exporter.container"}}
{{ $release := include "base.name.release" . }}
{{- $flags := fromJson (include "mw.helpers.feature_flags" . ) -}}
# php-fpm exporter
- name: {{ $release }}-php-fpm-exporter
  image: {{ .Values.docker.registry }}/prometheus-php-fpm-exporter:{{ .Values.php.exporter.version }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  {{- if $flags.native_sidecars }}
  restartPolicy: Always
  {{- end }}
  args: ["--endpoint=http://127.0.0.1:9181/fpm-status", "--addr=0.0.0.0:9118"]
  ports:
    - name: fpm-metrics
      containerPort: 9118
  livenessProbe:
    tcpSocket:
      port: 9118
  resources:
    requests:
{{ toYaml .Values.php.exporter.requests | indent 6 }}
    limits:
{{ toYaml .Values.php.exporter.limits | indent 6 }}
{{- if and .Values.main_app.prestop_sleep (not $flags.native_sidecars) }}
{{ include "base.helper.prestop" .Values.main_app.prestop_sleep | nindent 2}}
{{- end }}
{{- include "base.helper.restrictedSecurityContext" . | indent 2 }}
{{- end }}
