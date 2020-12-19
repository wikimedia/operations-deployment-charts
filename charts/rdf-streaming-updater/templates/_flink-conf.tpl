{{- define "flink-conf" -}}
jobmanager.rpc.address: {{ template "wmf.releasename" . }}-jobmanager
taskmanager.numberOfTaskSlots: {{ .Values.main_app.config.task_slots }}
blob.server.port: 6124
jobmanager.rpc.port: 6123
taskmanager.rpc.port: 6122
queryable-state.proxy.ports: 6125
jobmanager.memory.process.size: {{ .Values.main_app.config.job_manager_mem }}
taskmanager.memory.process.size: {{ .Values.main_app.config.task_manager_mem }}
parallelism.default: {{ .Values.main_app.config.parallelism }}
metrics.reporters: prom
metrics.reporter.prom.class: org.apache.flink.metrics.prometheus.PrometheusReporter
metrics.reporter.prom.port: 9102
swift.service.thanos-swift.auth.url: {{ .Values.main_app.config.thanos_auth_url }}
swift.service.thanos-swift.username: {{ .Values.main_app.config.thanos_username }}
swift.service.thanos-swift.apikey: {{ .Values.config.private.thanos_api_key}}
{{- end -}}
