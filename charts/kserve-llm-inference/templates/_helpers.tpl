{{/* Common labels. `app-wmf` rather than `app`, because KServe sets `app` itself. */}}
{{- define "kserve-llm-inference.labels" -}}
app-wmf: {{ .Chart.Name }}
chart: {{ .Chart.Name }}-{{ .Chart.Version }}
release: {{ .Release.Name }}
{{- end -}}

{{- define "kserve-llm-inference.vllmImage" -}}
{{ .Values.registry }}/{{ .Values.vllm.image }}:{{ .Values.vllm.version }}
{{- end -}}

{{/*
  spec.router.route.http.spec for one service: the same contract as
  templates/virtualservice.yaml -- host <service>.<namespace>.<domain>, /openai/v1/ and
  /v1/ -- so rest-gateway needs no change. Inference paths go through the InferencePool;
  everything else under /v1/ (e.g. /v1/models, /v1/embeddings) goes straight to the
  workload Service, as upstream does, because the endpoint picker only parses inference
  requests.

  Rendered here rather than in the kserve-config-llm-router-route preset: the CRD
  defaults `rules` on any route spec the service sets, and the controller merges the
  service spec last, so a preset's rules would always be replaced.

  Child names mirror the controller's kmeta.ChildName, which hashes names over 63
  characters; the fail keeps the two from silently diverging.

  Args: dict "root" $ "name" <service name> "svc" <service values>.
*/}}
{{- define "kserve-llm-inference.routerRoute" -}}
{{- $root := .root }}
{{- $r := $root.Values.routing }}
{{- $poolName := printf "%s-inference-pool" .name }}
{{- $workloadSvc := printf "%s-kserve-workload-svc" .name }}
{{- if gt (len $workloadSvc) 63 }}{{ fail (printf "llm_inference_services.%s: name too long for router (max %d characters)" .name (sub 63 (len "-kserve-workload-svc"))) }}{{ end }}
{{- $port := $root.Values.monitoring.port }}
{{- $timeout := .svc.timeout | default $r.timeout }}
{{- $openaiPrefix := trimSuffix "/" $r.openaiPrefix -}}
hostnames:
  - {{ printf "%s.%s.%s" .name $root.Release.Namespace $r.domain }}
rules:
{{- range $prefix := list $openaiPrefix "" }}
{{- range $path := list "completions" "chat/completions" "responses" }}
  - backendRefs:
      - group: inference.networking.k8s.io
        kind: InferencePool
        name: {{ $poolName }}
        port: {{ $port }}
    matches:
      - path:
          type: PathPrefix
          value: {{ printf "%s/v1/%s" $prefix $path }}
    {{- if $prefix }}
    filters:
      - type: URLRewrite
        urlRewrite:
          path:
            type: ReplacePrefixMatch
            replacePrefixMatch: {{ printf "/v1/%s" $path }}
    {{- end }}
    timeouts:
      request: {{ $timeout }}
{{- end }}
  - backendRefs:
      - kind: Service
        name: {{ $workloadSvc }}
        port: {{ $port }}
    matches:
      - path:
          type: PathPrefix
          value: {{ printf "%s/v1/" $prefix }}
    {{- if $prefix }}
    filters:
      - type: URLRewrite
        urlRewrite:
          path:
            type: ReplacePrefixMatch
            replacePrefixMatch: /v1/
    {{- end }}
    timeouts:
      request: {{ $timeout }}
{{- end }}
{{- end -}}
