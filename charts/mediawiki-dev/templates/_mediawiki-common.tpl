{{/*
Templates for common sections of container specs
*/}}

{{- define "mediawiki-env" -}}
env:
  - name: SERVICE_IDENTIFIER
    value: {{ template "wmf.releasename" . }}
{{- if .Values.main_app.usel10nCache }}
  - name: L10N_CACHE
    value: /tmp/l10n-cache
{{- end }}
{{- range $k, $v := .Values.config.public }}
  - name: {{ $k | upper }}
    value: {{ tpl $v $ | quote }}
{{- end }}
{{- range $k, $v := .Values.config.private }}
  - name: {{ $k | upper }}
    valueFrom:
      secretKeyRef:
        name: {{ template "wmf.releasename" $ }}-secret-config
        key: {{ $k }}
{{- end }}
{{- end -}}


{{- define "mediawiki-volumeMounts" -}}
volumeMounts:
{{- with .Values.main_app.volumeMounts }}
{{ toYaml . | indent 2 }}
{{- end }}
  - name: secret-volume
    mountPath: /var/config
    readOnly: false
{{- if .Values.main_app.usel10nCache }}
  - name: l10n-cache
    mountPath: /tmp/l10n-cache
    readOnly: false
{{- end }}
{{- end -}}

{{- define "mediawiki-volumes" -}}
volumes:
  - name: secret-volume
    secret:
      secretName: {{ include "wmf.releasename" . }}-secret-files
      items:
      - key: LocalSettings.php
        path: LocalSettings.php
        mode: 0555
      - key: setup.sh
        path: setup.sh
        mode: 0555
{{- if .Values.main_app.usel10nCache }}
      - key: setup-l10n.sh
        path: setup-l10n.sh
        mode: 0555
  - name: l10n-cache
    hostPath:
      path: {{ .Values.main_app.l10nNodePath | required "main_app.l10nNodePath is required when main_app.usel10nCache is true" }}
      type: DirectoryOrCreate
{{- end }}
{{- with .Values.main_app.volumes }}
{{ toYaml . | indent 2 }}
{{- end }}
{{- end -}}
