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
  {{- if .Values.monitoring.enabled }}
  ports:
    - name: {{ .Values.monitoring.portName | quote }}
      containerPort: {{ .Values.monitoring.port }}
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
{{ include "limits" . | indent 2}}
  {{- with .Values.volumeMounts }}
  volumeMounts:
    {{- toYaml . | nindent 10 }}
  {{- end }}
{{- end }}
