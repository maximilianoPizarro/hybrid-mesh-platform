{{- define "industrial-edge.domain" -}}
{{ .Values.clusterDomain | default .Values.global.localClusterDomain | default "apps.cluster.example.com" }}
{{- end -}}

{{- define "industrial-edge-stormshift.clusterName" -}}
{{- required "industrial-edge-stormshift: set clusterName override to east or west (Kafka advertisedHost + EndpointSlice)" .Values.clusterName -}}
{{- end -}}
