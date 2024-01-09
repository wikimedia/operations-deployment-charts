apiVersion: crd.projectcalico.org/v1
kind: NetworkPolicy
metadata:
  {{- include "base.meta.metadata" (dict "Root" .) | indent 2 }}
spec:
  types:
    - Egress
  selector: app == "{{ template "base.name.chart" . }}" && release == "{{ .Release.Name }}"
  # Allow accessing the K8s API.
  egress:
    - action: Allow
      destination:
        services:
          name: kubernetes
          namespace: default
