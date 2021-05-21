{{- define "flink-conf" -}}
{{- if .Values.main_app.config.additional_flink_settings }}
{{- toYaml .Values.main_app.config.additional_flink_settings }}
{{- end}}

# We do not set this value, we use --host from the command line to pass the POD IP
# we want the job manager to expose itself as its unique ip so that HA leader election
# works properly as opposed to the ClusterIP service name
#jobmanager.rpc.address: POD_IP

taskmanager.numberOfTaskSlots: {{ .Values.main_app.config.task_slots }}
blob.server.port: {{ .Values.main_app.config.blob_server_port }}
jobmanager.rpc.port: {{ .Values.main_app.config.jobmanager_rpc_port }}
taskmanager.rpc.port: {{ .Values.main_app.config.taskmanager_rpc_port }}
queryable-state.proxy.ports: {{ .Values.main_app.config.queryable_state_proxy_port }}
jobmanager.memory.process.size: {{ .Values.main_app.config.job_manager_mem }}
taskmanager.memory.process.size: {{ .Values.main_app.config.task_manager_mem }}
rest.port: {{ .Values.service.port.targetPort }}
parallelism.default: {{ .Values.main_app.config.parallelism }}
metrics.reporters: prom
metrics.reporter.prom.class: org.apache.flink.metrics.prometheus.PrometheusReporter
metrics.reporter.prom.port: {{ .Values.main_app.config.prometheus_reporter_port }}
swift.service.thanos-swift.auth.url: {{ .Values.main_app.config.swift_auth_url }}
swift.service.thanos-swift.username: {{ .Values.main_app.config.swift_username }}
swift.service.thanos-swift.apikey: {{ .Values.config.private.swift_api_key}}
kubernetes.cluster-id:  {{ .Values.main_app.config.cluster_id}}
kubernetes.namespace: {{ .Release.Namespace}}
high-availability: org.apache.flink.kubernetes.highavailability.KubernetesHaServicesFactory
high-availability.storageDir: {{ .Values.main_app.config.ha_storage_dir}}
restart-strategy: fixed-delay
restart-strategy.fixed-delay.attempts: 10
{{- end -}}
