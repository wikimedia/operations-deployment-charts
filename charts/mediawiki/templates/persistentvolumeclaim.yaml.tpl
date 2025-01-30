{{- $flags := fromJson (include "mw.feature_flags" . ) -}}
{{- if (and $flags.dumps .Values.dumps.persistence.enabled) }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
    name: {{ .Values.dumps.persistence.claim_name }}
spec:
    accessModes:
        - ReadWriteMany
    volumeMode: Filesystem
    storageClassName: {{ .Values.dumps.persistence.storage_class | default "override_me" }}
    resources:
        requests:
            storage: {{ .Values.dumps.persistence.size | default "10Gi" }}
{{- end }}