{{- define "ferretdb.container" }}
{{- $release := include "base.name.release" . }}
- name: {{ $release }}-ferretdb
  image: {{ $.Values.docker.registry }}/{{ $.Values.ferretdb.image }}:{{ $.Values.ferretdb.version }}
  imagePullPolicy: {{ .Values.docker.pull_policy }}
  ports:
    - containerPort: {{ $.Values.ferretdb.port }}
  livenessProbe: {{ $.Values.ferretdb.liveness_probe | toYaml | nindent 4 }}
  readinessProbe: {{ $.Values.ferretdb.readiness_probe | toYaml | nindent 4 }}
  env:
  {{- range $k, $v := .Values.ferretdb.config }}
    - name: FERRETDB_{{ $k | upper }}
      value: {{ $v | quote }}
  {{- end }}
  {{- include "base.helper.resources" $.Values.ferretdb.resources | indent 2 }}
  {{- include "base.helper.restrictedSecurityContext" . | nindent 2 }}
  volumeMounts:
{{- end }}
