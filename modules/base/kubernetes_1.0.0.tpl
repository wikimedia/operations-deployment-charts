{{/* Create kubernetes master/api environment variables to replace the standard ones to allow for successfull verification of TLS certs.
Values are provided via puppet profile::kubernetes::deployment_server::general */}}
{{- define "base.kubernetes.ApiEnv" -}}
- name: KUBERNETES_PORT_443_TCP_ADDR
  value: "{{ .Values.kubernetesApi.host }}"
- name: KUBERNETES_SERVICE_HOST
  value: "{{ .Values.kubernetesApi.host }}"
- name: KUBERNETES_SERVICE_PORT
  value: "{{ .Values.kubernetesApi.port }}"
- name: KUBERNETES_SERVICE_PORT_HTTPS
  value: "{{ .Values.kubernetesApi.port }}"
- name: KUBERNETES_PORT
  value: "tcp://{{ .Values.kubernetesApi.host }}:{{ .Values.kubernetesApi.port }}"
- name: KUBERNETES_PORT_443_TCP
  value: "tcp://{{ .Values.kubernetesApi.host }}:{{ .Values.kubernetesApi.port }}"
- name: KUBERNETES_PORT_443_TCP_PORT
  value: "{{ .Values.kubernetesApi.port }}"
{{- end -}}