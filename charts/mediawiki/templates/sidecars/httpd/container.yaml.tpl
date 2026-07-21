{{define "sidecars.httpd.container"}}
{{ $release := include "base.name.release" . }}
{{- $flags := fromJson (include "mw.helpers.feature_flags" . ) -}}
### The apache httpd container
# TODO: set up logging. See T265876
# TODO: fix virtualhosts in puppet so that the port is set to APACHE_RUN_PORT
- name: {{ $release }}-httpd
  image: {{.Values.docker.registry }}/{{ .Values.mw.httpd.image_tag }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  env:
  - name: FCGI_MODE
    value: {{ .Values.php.fcgi_mode }}
  - name: SERVERGROUP
    value: {{ .Values.php.servergroup }}
  - name: APACHE_RUN_PORT
    value: "{{ .Values.php.httpd.port }}"
  # Set the pod name as the value of the Server: header.
  - name: SERVER_SIGNATURE
    valueFrom:
      fieldRef:
        fieldPath: metadata.name
  - name: LOG_FORMAT
    value: {{ .Values.mw.logging.format }}
  # Do not log monitoring requests
  - name: LOG_SKIP_SYSTEM
    value: "1"
  ports:
  - name: httpd
    containerPort: {{ .Values.php.httpd.port }}
  # PHP monitoring port
  - name: php-metrics
    containerPort: 9181
  livenessProbe:
    tcpSocket:
      port: httpd
  readinessProbe:
    httpGet:
      # this is the simplest php script you can think of - it just returns OK.
      # This way, we're just testing that apache + php-fpm are ready.
      # mcrouter, if enabled, should have its own readiness probe probably.
      path: /healthz
      port: php-metrics
{{- if .Values.main_app.prestop_sleep }}
{{ include "base.helper.prestop" .Values.main_app.prestop_sleep | nindent 2}}
{{- end }}
  resources:
    requests:
{{ toYaml .Values.php.httpd.requests | indent 6 }}
    limits:
{{ toYaml .Values.php.httpd.limits | indent 6 }}
  volumeMounts:
  {{- if .Values.mw.httpd.enabled }}
  {{- if eq .Values.php.fcgi_mode "FCGI_UNIX" }}
    # Mount the shared socket volume
  - name: shared-socket
    mountPath: /run/shared
  {{- end }}
  {{- end }}
  {{- if .Values.debug.php.enabled }}
  - name: {{ $release }}-php-debug
    mountPath: /srv/mediawiki/w/debug
  {{- end }}
  {{- if .Values.mw.httpd.enabled }}
  # Note: we use subpaths here. Given subpaths are implemented with bind mounts,
  # they won't be updated when the configmap is updated.
  # This is ok because we're re-deploying the pods when that happens.
  {{- range .Values.mw.sites }}
  - name: {{ $release }}-httpd-sites
    mountPath: /etc/apache2/sites-enabled/{{ template "mw-vhost-filename" . }}
    subPath: {{ template "mw-vhost-filename" . }}
  {{- end }}
  {{- if .Values.mw.httpd.additional_config }}
  # Allow us to inject configurations *before* everything else is evaluated
  # To this end we also pick a non-descriptive name that OTOH guarantees
  # the configuration will be loaded soon.
  # See apache.conf in the mediawiki-httpd image to see precisely when this is loaded.
  - name: {{ $release }}-httpd-early
    mountPath: /etc/apache2/conf-enabled/00-aaa.conf
    subPath: 00-aaa.conf
  {{- end }}
  {{- end }}
{{- include "base.helper.restrictedSecurityContext" . | indent 2 }}
{{- end }}