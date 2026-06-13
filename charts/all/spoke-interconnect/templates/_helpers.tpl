{{- define "spoke-interconnect.clusterName" -}}
{{- if .Values.clusterName -}}
{{- .Values.clusterName -}}
{{- else if and .Values.clusterGroup .Values.clusterGroup.name -}}
{{- .Values.clusterGroup.name -}}
{{- else -}}
{{- .Values.global.localClusterName | default "" -}}
{{- end -}}
{{- end -}}
