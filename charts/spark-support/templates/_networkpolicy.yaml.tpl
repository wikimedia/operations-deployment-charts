
{{- define "networkpolicy.kyuubi" }}
---
apiVersion: crd.projectcalico.org/v1
kind: NetworkPolicy
metadata:
  name: spark-driver-to-kyuubi
  {{- include "base.meta.labels" . | indent 2 }}
spec:
  selector: 'component == "kyuubi"'
  ingress:
    - action: Allow
      protocol: TCP
      source:
        selector: "spark-role == 'driver"
        namespaceSelector: 'kubernetes.io/metadata.name == "{{ $.Release.Namespace }}"'
      destination:
        ports:
        {{- range $name, $frontend := .Values.kyuubi.server }}
        {{- if $frontend.enabled }}
          - {{ tpl $frontend.service.port $ }}
        {{- end }}
        {{- end }}
{{- end }}