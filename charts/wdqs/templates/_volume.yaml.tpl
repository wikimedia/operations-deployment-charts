{{- define "app.backend.volume" }}
- name: data-dir
  {{- if eq .Values.backend.volume.storageType "emptyDir" }}
  emptyDir:
    sizeLimit: {{ $.Values.backend.volume.size }}
  {{- else }}
  persistentVolumeClaim:
    claimName: {{ template "base.name.release" . }}-backend-pvc
  {{- end }}
{{- end }}
