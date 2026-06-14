{{- define "industrial-edge-data-lake.clusterName" -}}
{{- required "industrial-edge-data-lake: set clusterName override to east or west (Kafka advertisedHost + EndpointSlice)" .Values.clusterName -}}
{{- end -}}
