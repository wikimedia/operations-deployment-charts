{{ define "lamp.deployment" }}
{{ $release := include "base.name.release" . }}
{{- $flags := fromJson (include "mw.helpers.feature_flags" . ) -}}
{{- if $flags.web }}
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
### The MediaWiki container
- name: {{ $release }}-app
  image: {{ .Values.docker.registry }}/{{ .Values.main_app.image }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  {{- if $flags.mercurius }}
  command: ["/usr/bin/mercurius"]
  args: [
         {{- if .Values.mercurius.debug }}
         "--debug",
         {{- end }}
         "--metrics-address",
         "0.0.0.0:{{.Values.mercurius.monitor_port}}"
        ]
  {{- else if $flags.job }}
  command: {{ .Values.mwscript.command }}
  args:
{{ .Values.mwscript.args | toYaml | indent 4 }}
  # If --file isn't passed to the wrapper script, nothing will be mounted to
  # /data, but it will be (harmlessly) created by setting workingDir here.
  workingDir: /data
  tty: {{ .Values.mwscript.tty }}
  stdin: {{ .Values.mwscript.stdin }}
  stdinOnce: {{ .Values.mwscript.stdin }}
  {{- else if $flags.cron }}
  # MediaWiki cronjobs may require a tty to run, as a first approximation make it always true.
  # TODO: Eventually, determine which cronjobs need a tty and make it configurable.
  tty: true
  command: ["/bin/bash"]
  args: ["-c", {{ .JobConfig.command | quote }}]
  {{- end }}
  {{- if .Values.php.slowlog_timeout }}
  securityContext:
    # NOTE: PSS does not allow hostPath volumes under any profile other than
    # privileged. As such, securityContext has no ability to allow-list them,
    # unlike PSP (where it was only validating anyway). Same goes for allowed
    # volume types.
    allowPrivilegeEscalation: false
    capabilities:
      drop: ["ALL"]
      add: ["SYS_PTRACE"] # This is needed to produce a slow log
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  {{- else }}
  {{- include "base.helper.restrictedSecurityContext" . | indent 2 }}
  {{- end }}
{{- if .Values.main_app.prestop_sleep }}
{{ include "base.helper.prestop" .Values.main_app.prestop_sleep | nindent 2}}
{{- end }}
  env:
  - name: SERVERGROUP
    value: {{ .Values.php.servergroup }}
  {{- if .Values.mw.httpd.enabled }}
  - name: FCGI_MODE
    value: {{ .Values.php.fcgi_mode }}
  - name: FCGI_URL
    {{- if eq .Values.php.fcgi_mode "FCGI_TCP" }}
    value: "0.0.0.0:9000"
    {{- else }}
    value: "unix:///run/shared/fpm-www.sock"
    {{- end }}
    {{- end }}
  - name: PHP__opcache__memory_consumption
    value: "{{ .Values.php.opcache.size }}"
  - name: PHP__opcache__max_accelerated_files
    value: "{{ .Values.php.opcache.nofiles }}"
  - name: PHP__opcache__interned_strings_buffer
    value: "{{ .Values.php.opcache.interned_strings_buffer}}"
  - name: PHP__auto_prepend_file
    value: "{{ .Values.php.auto_prepend_file }}"
  - name: FPM__request_terminate_timeout
    value: "{{ .Values.php.timeout }}"
  - name: PHP__apc__shm_size
    value: {{ .Values.php.apc.size }}M
  - name: FPM__pm__max_children
    value: "{{ .Values.php.workers }}"
  - name: FPM__request_slowlog_timeout
    value: "{{ .Values.php.slowlog_timeout }}"
  - name: PHP__display_errors
    value: "{{ .Values.php.display_errors }}"
  - name: PHP__error_reporting
    value: "{{ .Values.php.error_reporting }}"
  - name: PHP__pcre__backtrack_limit
    value: "{{ .Values.php.pcre_backtrack_limit }}"
  - name: PHP__max_execution_time
    value: "{{ .Values.php.max_execution_time }}"
  {{- if .Values.php.devel_mode }}
  - name: PHP__opcache__validate_timestamps
    value: "1"
  - name: PHP__opcache__revalidate_freq
    value: "0"
  - name: FPM__catch_workers_output
    value: "1"
  {{- end }}
  - name: PHP__error_log
  {{- if .Values.mw.logging.rsyslog }}
    value: /var/log/php-fpm/error.log
  {{- else }}
    value: "{{ .Values.php.error_log }}"
  {{- end }}
  {{- if .Values.mw.mcrouter_server }}
  - name: MW__MCROUTER_SERVER
    value: "{{ .Values.mw.mcrouter_server }}"
  {{- end }}
  - name: FCGI_ALLOW
    value: "127.0.0.1"
  {{- if .Values.mw.logging.rsyslog }}
  - name: FPM__slowlog
    value: /var/log/php-fpm/slowlog.log
  {{- end }}
  {{- if $flags.mercurius }}
  - name: MERCURIUS_CFG
    value: MERCURIUS_JOB_PLACEHOLDER
  {{- end }}
  # Variables that will be made available to php-fpm and cli scripts.
  {{- range $k, $v := .Values.php.envvars }}
  {{- if not (quote $v | empty) }}
  - name: {{ $k | upper }}
    value: {{ $v | quote }}
  {{- end }}
  {{- end }}
  # Variables that will be avaliable only to cli scripts
  {{- range $k, $v := .Values.config.public }}
  - name: {{ $k | upper }}
    value: {{ $v | quote }}
  {{- end }}
  # Variables set by the mw-script wrapper
  {{- range $k, $v := .Values.mwscript.env }}
  - name: {{ $k | upper }}
    value: {{ $v | quote }}
  {{- end }}
  {{- if $flags.web }}
  # See T276908
  livenessProbe:
  {{- if eq .Values.php.fcgi_mode "FCGI_TCP" }}
    tcpSocket:
      port: 9000
  {{- else }}
{{/* TODO: add netcat-openbsd to the php image and run nc -U -z /run/shared/fpm-www.sock instead*/}}
    exec:
      command:
      - /usr/bin/test
      - -S
      - /run/shared/fpm-www.sock
  {{- end }}
    initialDelaySeconds: 1
    periodSeconds: 5
  {{- end }}
  {{- if $flags.mercurius }}
  ports:
   - name: merc-metrics
     containerPort: {{ .Values.mercurius.monitor_port }}
  {{- end }}
  resources:
    requests:
    {{- if .Values.main_app.requests.auto_compute }}
      # CPU calculation:
      # Minimum 1 whole CPU
      # Multiply the amount of cpu_per_worker (float, unit: cpu, ex: 0.5 is half a CPU per worker)
      # by the number of configured workers + 1 (to take into account the main php-fpm process)
      cpu: {{ maxf 1 (mulf (add .Values.php.workers 1) .Values.php.cpu_per_worker) }}
      # RAM calculation:
      # Multiply 50% of the amount of memory_per_worker by the number of workers (ignoring the main php-fpm process)
      # Add 50% of the opcache size and the apc size (close to the average real consumption)
      memory: {{ add (mul .Values.php.workers (div .Values.php.memory_per_worker 2)) (div .Values.php.opcache.size 2) (div .Values.php.apc.size 2) }}Mi
    {{- else }}
      cpu: {{ .Values.main_app.requests.cpu }}
      memory: {{ .Values.main_app.requests.memory }}
    {{- end }}
    {{- if and .Values.main_app.limits.enforce }}
    limits:
      {{- if .Values.main_app.limits.cpu }}
      cpu: {{ .Values.main_app.limits.cpu }}
      {{- end }}
      {{- if .Values.main_app.limits.auto_compute }}
      # RAM calculation:
      # Multiply the amount of memory_per_worker by the number of workers (ignoring the main php-fpm process)
      # Add 50% of the opcache size and the apc size (close to the average real consumption)
      memory: {{ add (mul .Values.php.workers .Values.php.memory_per_worker) (div .Values.php.opcache.size 2) (div .Values.php.apc.size 2) }}Mi
      {{- else if .Values.main_app.limits.memory }}
      memory: {{ .Values.main_app.limits.memory }}
      {{- end }}
    {{- end }}
  volumeMounts:
  # TODO: use an env variable for this.
  - name: {{ $release }}-wikimedia-cluster
    mountPath: /etc/wikimedia-cluster
    subPath: wikimedia-cluster
  {{- if .Values.mw.mail_host }}
  # mount the volume as the www-data home. This allows us to change
  # the configuration of this configmap without causing a mediawiki
  # redeployment as well, which we'd need if we were using a subpath.
  - name: {{ $release }}-mail
    mountPath: /var/www
  {{ end -}}
  {{- if eq .Values.php.fcgi_mode "FCGI_UNIX" }}
  # Mount the shared socket volume
  - name: shared-socket
    mountPath: /run/shared
  {{ end -}}
  {{- if .Values.mw.wmerrors }}
  # php-wmerrors configuration
  - name: {{ $release }}-wmerrors
    mountPath: /etc/wmerrors
  {{ end -}}
  {{- if .Values.mw.logging.rsyslog }}
  - name: php-logging
    mountPath: /var/log/php-fpm
  {{- end -}}
  {{- if .Values.debug.php.enabled }}
  - name: {{ $release }}-php-debug
    mountPath: /srv/mediawiki/w/debug
  {{- end }}
  {{- if .Values.mw.geoip }}
  # GeoIP data
  - name: {{ $release }}-geoip
    mountPath: /usr/share/GeoIP/
    readOnly: true
  - name: {{ $release }}-geoipinfo
    mountPath: /usr/share/GeoIPInfo/
    readOnly: true
  {{- end }}
  {{- if .Values.mw.experimental.enabled }}
  # Mount /srv/mediawiki if experimental is enabled
  - name: {{ $release }}-experimental-mediawiki
    mountPath: /srv/mediawiki
    readOnly: true
  {{- end -}}
  {{- if .Values.mw.parsoid.testing }}
  # Mount /srv/parsoid-testing if parsoid is enabled
  - name: {{ $release }}-parsoid-testing-mediawiki
    mountPath: /srv/parsoid-testing
    readOnly: true
  {{- end -}}
  {{- if .Values.php.envvars }}
  # PHP environment variables
  - name: {{ $release }}-php-envvars
    mountPath: /etc/php/{{ .Values.php.version }}/fpm/env
    readOnly: true
  {{- end -}}
  {{- if and ($flags.job) (.Values.mwscript.textdata) }}
  - name: {{ $release }}-mwscript-textdata
    mountPath: /data
    readOnly: true
  {{- end -}}
  {{- if and ($flags.job) (.Values.mwscript.dblist_contents) }}
  - name: {{ $release }}-mwscript-dblist
    mountPath: /srv/mediawiki/dblists/mwscript.dblist
    subPath: mwscript.dblist
    readOnly: true
  {{- end -}}
  {{- if $flags.mercurius }}
  - name: {{ $release }}-mercurius-config
    mountPath: /etc/mercurius
    readOnly: true
  - name: {{ $release }}-mercurius-script
    mountPath: /usr/bin/mercurius-wrapper
    subPath: mercurius-wrapper
  {{- end -}}
  {{- if (and $flags.dumps .Values.dumps.persistence.enabled) }}
  - name: {{ $release }}-dumps
    mountPath: {{ .Values.dumps.persistence.mount_path }}
  {{- end -}}
  {{- if $flags.cron }}
  - name: {{ $release }}-cron-captcha
    mountPath: /etc/fancycaptcha/
    readOnly: true
  {{- end -}}

{{- if .Values.monitoring.enabled }}
# Add the following exporters:
{{- if $flags.web }}
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
# php-fpm exporter
- name: {{ $release }}-php-fpm-exporter
  image: {{ .Values.docker.registry }}/prometheus-php-fpm-exporter:{{ .Values.php.exporter.version }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
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
{{- if .Values.main_app.prestop_sleep }}
{{ include "base.helper.prestop" .Values.main_app.prestop_sleep | nindent 2}}
{{- end }}
{{- include "base.helper.restrictedSecurityContext" . | indent 2 }}
{{- end }}
{{- end }}
{{ end }}
