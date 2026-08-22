## istio 1.4.0
- Dependency: mesh.name 1.1 => 1.2
- Fix "depends" field in module.json. Previously, the module's dependencies would be ignored by
  sextant during upgrade operations. Note that this is only done for 1.4.0 - i.e., prior versions
  are not retroactively fixed.

## istio 1.3.0
- If .Values.ingress.routeHosts is non-empty, it will now always take precedent over the host list
  generated from .Values.ingress.gatewayHosts.* when populating the VirtualService host list. Prior
  to now, this was only supported when .Values.ingress.existingGatewayName was set.

## istio 1.1.0
- Drop .Values.ingress.staging and .Values.ingress.mlstaging
- Use a per environment list of domains instead of a hardcoded one for gatewayHosts
  (.Values.ingress.gatewayHosts.domains, defaults to .Values.mesh.certmanager.domains
  as that is already set per cluster/environment currently)
