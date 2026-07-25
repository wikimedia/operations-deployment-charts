{{- define "app.backend.pvc" }}
- metadata:
    name: data-dir
  spec:
    accessModes: [ReadWriteOnce]
    storageClassName: {{ $.Values.backend.volume.storageClass }}
    resources:
      requests:
        storage: {{ $.Values.backend.volume.size }}
{{- end }}
