{{/*
Templates for common sections of container specs
*/}}

{{- define "mediawiki-env" -}}
env:
  - name: SERVICE_IDENTIFIER
    value: {{ template "wmf.releasename" . }}
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
{{- with .Values.main_app.volumes }}
{{ toYaml . | indent 2 }}
{{- end }}
{{- end -}}
