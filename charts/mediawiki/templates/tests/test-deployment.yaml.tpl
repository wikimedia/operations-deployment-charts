apiVersion: batch/v1
kind: Job
metadata:
  name: test-{{ template "wmf.releasename" . }}
  {{- include "mw.labels" . | indent 2 }}
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    spec:
      containers:
      - name: test-{{ template "wmf.releasename" . }}
        image: {{ .Values.docker.registry }}/{{ .Values.common_images.wmfdebug }}
        command:
          - curl
          - -sSf
          - --connect-to
          - "test.wikipedia.org:80:{{ template "wmf.releasename" . }}:{{ .Values.service.port.port }}"
          - -H
          - "X-Forwarded-Proto: https"
          - http://test.wikipedia.org/wiki/Main_Page
      restartPolicy: Never
