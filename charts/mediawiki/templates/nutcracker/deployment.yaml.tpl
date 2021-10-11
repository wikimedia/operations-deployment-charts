{{- define "nutcracker.deployment" -}}
# nutcracker image
# TODO: check if we would be better off with a daemonset
- name: {{ template "wmf.releasename" . }}-nutcracker
  image: {{ .Values.docker.registry }}/{{ .Values.common_images.nutcracker.nutcracker }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  ports:
  {{- range .Values.mw.nutcracker.pools }}
  - name: nc-{{ .name | lower }}
    containerPort: {{ .port }}
  {{- end }}
  - name: nc-stats
    containerPort: 22222
  livenessProbe:
    tcpSocket:
      port: nc-stats
  {{- with .Values.mw.nutcracker.resources }}
  resources:
    requests:
{{ toYaml .requests | indent 6 }}
    limits:
{{ toYaml .limits | indent 6 }}
  {{- end }}
  volumeMounts:
    - name: {{ template "wmf.releasename" . }}-nutcracker-config
      mountPath: /etc/nutcracker
{{- if .Values.monitoring.enabled }}
- name: {{ template "wmf.releasename" . }}-nutcracker-exporter
  image: {{ .Values.docker.registry }}/{{ .Values.common_images.nutcracker.exporter }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  ports:
  - name: nc-metrics
    containerPort: 9191
  livenessProbe:
    tcpSocket:
      port: nc-metrics
{{- end -}}
{{- end -}}