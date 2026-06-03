{{- define "app.backend.pvc" }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ template "base.name.release" . }}-backend-pvc
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem
  resources:
    requests:
      storage: {{ $.Values.backend.volume.size }}
  storageClassName: {{ $.Values.backend.volume.storageClass }}
{{- end }}
