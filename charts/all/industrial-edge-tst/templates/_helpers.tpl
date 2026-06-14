{{- define "industrial-edge.domain" -}}
{{ .Values.clusterDomain | default .Values.global.localClusterDomain | default "apps.cluster.example.com" }}
{{- end -}}

{{- define "industrial-edge-tst.clusterName" -}}
{{- required "industrial-edge-tst: set clusterName override to east or west (Kafka advertisedHost + EndpointSlice)" .Values.clusterName -}}
{{- end -}}
