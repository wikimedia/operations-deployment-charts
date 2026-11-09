{{/*
Egress rules shared by all Calico network policies: DNS and the Kubernetes API server,
both matched through their Services. Matching the API server this way works whether
or not it runs as a pod.
*/}}
{{- define "keda.calicoEgressRules" -}}
# Allow DNS resolution
- action: Allow
  protocol: UDP
  destination:
    services:
      name: kube-dns
      namespace: kube-system
- action: Allow
  protocol: TCP
  destination:
    services:
      name: kube-dns
      namespace: kube-system
# Allow access to the Kubernetes API server
- action: Allow
  destination:
    services:
      name: kubernetes
      namespace: default
{{- end }}
