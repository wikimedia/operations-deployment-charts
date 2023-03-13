{{- define "limits" }}
resources:
  requests:
{{ toYaml .Values.app.requests | indent 4 }}
  limits:
{{ toYaml .Values.app.limits | indent 4 }}
{{ end -}}

{{/* default scaffolding for containers */}}
{{- define "default.containers" }}
# The main application container
- name: {{ template "base.name.release" . }}
  image: "{{ .Values.docker.registry }}/{{ .Values.app.image }}:{{ .Values.app.version }}"
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  {{- if .Values.app.command }}
  command:
    {{- range .Values.app.command }}
    - {{ . }}
    {{- end }}
  {{- end }}
  args:
  - -v={{ .Values.logLevel }}
  - -logtostderr
  - -namespace={{ .Values.watchNamespace }}
  - -enable-ui-service=false
  - -controller-threads={{ .Values.controllerThreads }}
  - -resync-interval={{ .Values.resyncInterval }}
  - -enable-batch-scheduler={{ .Values.batchScheduler.enable }}
  - -label-selector-filter={{ .Values.labelSelectorFilter }}
  {{- if .Values.monitoring.enable }}
  - -enable-metrics=true
  - -metrics-labels=app_type
  - -metrics-port={{ .Values.monitoring.port }}
  - -metrics-endpoint={{ .Values.monitoring.endpoint }}
  - -metrics-prefix={{ .Values.monitoring.prefix }}
  {{- end }}
  {{- if gt (int .Values.replicaCount) 1 }}
  - -leader-election=true
  - -leader-election-lock-namespace={{ default .Release.Namespace .Values.leaderElection.lockNamespace }}
  - -leader-election-lock-name={{ .Values.leaderElection.lockName }}
  {{- end }}
  {{- if .Values.webhook.enable }}
  - -enable-webhook=true
  - -webhook-svc-namespace={{ .Release.Namespace }}
  - -webhook-port={{ .Values.webhook.port }}
  - -webhook-timeout={{ .Values.webhook.timeout }}
  - -webhook-fail-on-error=true
  - -webhook-svc-name={{ template "base.name.release" . }}-webhook
  - -webhook-config-name={{ template "base.name.release" . }}-webhook-config
  - -webhook-namespace-selector=kubernetes.io/metadata.name={{ .Values.watchNamespace }}
  - -webhook-server-cert=/etc/webhook-certs/tls.crt
  - -webhook-server-cert-key=/etc/webhook-certs/tls.key
  - -webhook-ca-cert=/etc/webhook-certs/ca.crt
  {{- end }}
  {{- if or .Values.monitoring.enabled .Values.webhook.enable }}
  ports:
  {{- if or .Values.monitoring.enabled }}
    - name: {{ .Values.monitoring.portName | quote }}
      containerPort: {{ .Values.monitoring.port }}
  {{- end }}
  {{- if or .Values.webhook.enable }}
    - name: webhook
      containerPort: {{ .Values.webhook.port }}
  {{- end }}
  {{- end }}
  {{- if .Values.app.liveness_probe }}
  livenessProbe:
  {{- toYaml .Values.app.liveness_probe | nindent 4 }}
  {{- end }}
  {{- if .Values.app.readiness_probe }}
  readinessProbe:
  {{- toYaml .Values.app.readiness_probe | nindent 4 }}
  {{- end }}
  env:
    - name: SERVICE_IDENTIFIER
      value: {{ template "base.name.release" . }}
  {{- range $k, $v := .Values.config.public }}
    - name: {{ $k | upper }}
      value: {{ $v | quote }}
  {{- end }}
  {{- range $k, $v := .Values.config.private }}
    - name: {{ $k | upper }}
      valueFrom:
        secretKeyRef:
          name: {{ template "base.name.release" $ }}-secret-config
          key: {{ $k }}
  {{- end }}
{{- include "limits" . | indent 2}}
  {{- if or .Values.webhook.enable (ne (len .Values.volumeMounts) 0 ) }}
  volumeMounts:
  {{- end }}
    {{- if .Values.webhook.enable }}
    - name: webhook-certs
      mountPath: /etc/webhook-certs
    {{- end }}
  {{- with .Values.volumeMounts }}
  {{- toYaml . | nindent 10 }}
  {{- end }}
{{- end }}
