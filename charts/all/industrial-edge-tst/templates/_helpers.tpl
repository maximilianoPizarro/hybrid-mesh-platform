{{- define "industrial-edge.domain" -}}
{{ .Values.clusterDomain | default .Values.global.localClusterDomain | default "apps.cluster.example.com" }}
{{- end -}}
