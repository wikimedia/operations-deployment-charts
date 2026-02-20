{{- define "httpd_cas.container" }}
{{- $release := include "base.name.release" . }}
- name: {{ $release }}-httpd-cas
  image: {{ .Values.docker.registry }}/{{ .Values.httpd_cas.image }}:{{ .Values.httpd_cas.version }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  ports:
  - containerPort: {{ .Values.httpd_cas.port }}
    protocol: TCP
  env:
  - name: APACHE_RUN_PORT
    value: "{{ .Values.httpd_cas.port }}"
  {{- include "base.helper.resources" .Values.httpd_cas.resources | indent 2 }}
  {{- if .Values.httpd_cas.liveness_probe }}
  livenessProbe:
  {{- toYaml .Values.httpd_cas.liveness_probe | nindent 4 }}
  {{- end }}
  {{- if .Values.httpd_cas.readiness_probe }}
  readinessProbe:
  {{- toYaml .Values.httpd_cas.readiness_probe | nindent 4 }}
  {{- end }}
  volumeMounts:
    {{- toYaml .Values.httpd_cas.volumeMounts | nindent 4 }}
  {{- include "base.helper.restrictedSecurityContext" . | nindent 2 }}
{{- end }}

{{- define "httpd_cas.volume" }}
{{- with .Values.httpd_cas.volumes }}
{{ toYaml . }}
{{- end }}
{{- end -}}
