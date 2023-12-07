## istio 1.1.0
- Drop .Values.ingress.staging and .Values.ingress.mlstaging
- Use a per environment list of domains instead of a hardcoded one for gatewayHosts
  (.Values.ingress.gatewayHosts.domains, defaults to .Values.mesh.certmanager.domains
  as that is already set per cluster/environment currently)