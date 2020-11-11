{{- define "flink-conf" -}}
jobmanager.rpc.address: {{ template "wmf.releasename" . }}-jobmanager
taskmanager.numberOfTaskSlots: 2
blob.server.port: 6124
jobmanager.rpc.port: 6123
taskmanager.rpc.port: 6122
queryable-state.proxy.ports: 6125
jobmanager.memory.process.size: 1600m
taskmanager.memory.process.size: 1728m
parallelism.default: 1
metrics.reporters: prom
metrics.reporter.prom.class: org.apache.flink.metrics.prometheus.PrometheusReporter
metrics.reporter.prom.port: 9102
{{- end -}}
