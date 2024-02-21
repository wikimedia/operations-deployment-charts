apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: sidecar-job-controller-viewer
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: sidecar-job-controller-exec
rules:
  - apiGroups: [""]
    resources: ["pods/exec"]
    verbs: ["create", "get"]
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sidecar-job-controller
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: sidecar-job-controller-viewer
subjects:
  - kind: ServiceAccount
    name: sidecar-job-controller
    namespace: {{ .Release.Namespace }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: sidecar-job-controller-viewer
{{ range $namespace, $values := .Values.namespaces }}
{{- if $values.enableJobSidecarController }}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: sidecar-job-controller-exec
  namespace: {{ $namespace }}
subjects:
  - kind: ServiceAccount
    name: sidecar-job-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: sidecar-job-controller-exec
{{- end }}
{{- end }}
