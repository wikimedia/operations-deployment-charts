{{- define "mcrouter.deployment" -}}
# TODO: understand how to make mcrouter use the
# application CA when connecting to memcached via TLS
- name: {{ template "wmf.releasename" . }}-mcrouter
  image: {{ .Values.docker.registry }}/{{ .Values.common_images.mcrouter.mcrouter }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  {{- with .Values.mw.mcrouter }}
  env:
    - name: PORT
      value: "11213"
    - name: CONFIG
      value: "file:/etc/mcrouter/config.json"
    - name: ROUTE_PREFIX
      value: "{{ .route_prefix }}"
    - name: CROSS_REGION_TO
      value: "{{ .cross_region_timeout }}"
    - name: CROSS_CLUSTER_TO
      value: "{{ .cross_cluster_timeout }}"
    - name: NUM_PROXIES
      value: "{{ .num_proxies }}"
    - name: PROBE_TIMEOUT
      value: "{{ .probe_timeout }}"
    - name: TIMEOUTS_UNTIL_TKO
      value: "{{ .timeouts_until_tko }}"
    # We don't want to listen to TLS here.
    # TODO: check if it can connect with TLS without the TLS settings.
    - name: USE_SSL
      value: "no"
  {{- end }}
  ports:
  # Please note: this port is not exposed outside of the pod.
    - name: mcrouter
      containerPort: 11213
  livenessProbe:
    tcpSocket:
      port: mcrouter
  readinessProbe:
    exec:
      command:
        - /bin/healthz
  volumeMounts:
    - name: {{ template "wmf.releasename" . }}-mcrouter-config
      mountPath: /etc/mcrouter
  {{- with .Values.mw.mcrouter.resources }}
  resources:
    requests:
{{ toYaml .requests | indent 6 }}
    limits:
{{ toYaml .limits | indent 6 }}
  {{- end }}
{{- if .Values.monitoring.enabled }}
- name: {{ template "wmf.releasename" . }}-mcrouter-exporter
  image: {{ .Values.docker.registry }}/{{ .Values.common_images.mcrouter.exporter }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  args: ["--mcrouter.address", "127.0.0.1:11213", "-mcrouter.server_metrics", "-web.listen-address", ":9151" ]
  ports:
  # Port names are limited to 15 characters.
  - name: mcr-metrics
    containerPort: 9151
  livenessProbe:
    tcpSocket:
      port: mcr-metrics
  resources: {}
{{- end -}}
{{- end -}}