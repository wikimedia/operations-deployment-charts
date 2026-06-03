{{- define "app.backend.volume" }}
- name: data-dir
  {{- if eq .Values.backend.volume.storageClass "emptyDir" }}
  emptyDir:
    sizeLimit: {{ $.Values.backend.volume.size }}
  {{- else }}
  persistentVolumeClaim:
    claimName: {{ template "base.name.release" . }}-backend-pvc
  {{- end }}
{{- end }}
