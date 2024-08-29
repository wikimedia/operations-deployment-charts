{{/* Adapted from upstream: https://github.com/otherguy/k8s-controller-sidecars/blob/main/manifest.yml */}}
{{- $controllerNamespaces := list }}
{{- range $k, $v := .Values.namespaces }}
  {{- if $v.enableJobSidecarController }}
    {{- $controllerNamespaces = append $controllerNamespaces $k }}
  {{- end }}
{{- end }}
{{- if $controllerNamespaces }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ template "base.name.chart" . }}
  {{- include "base.meta.labels" . | indent 2 }}
spec:
  replicas: {{ .Values.replicas }}
  selector:
    {{- include "base.meta.selector" . | indent 4 }}
  template:
    metadata:
      labels:
        {{- include "base.meta.pod_labels" . | indent 8 }}
    spec:
      serviceAccountName: sidecar-job-controller
      containers:
        - name: sidecar-controller
          image: "{{ .Values.docker.registry }}/{{ .Values.app.image }}:{{ .Values.app.version }}"
          imagePullPolicy: {{ .Values.docker.pull_policy }}
          args:
            - "--namespaces"
            - {{ $controllerNamespaces | join "," }}
          resources:
{{ toYaml .Values.resources | indent 12 }}
{{- include "base.helper.restrictedSecurityContext" . | indent 10 }}
{{- end }}
