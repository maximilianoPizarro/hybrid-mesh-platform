{{/*
  Resolve apps ingress domain from VP global values (RHDP deployer.domain) or explicit override.
*/}}
{{- define "neuroface.clusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.clusterDomain | default $g.localClusterDomain | default $g.hubClusterDomain | default "apps.cluster.example.com" -}}
{{- end -}}

{{- define "neuroface.hubClusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.hubClusterDomain | default $g.hubClusterDomain | default (include "neuroface.clusterDomain" .) -}}
{{- end -}}

{{- define "neuroface.minioEndpoint" -}}
{{- $ms := .Values.yoloPpeServing.modelStorage | default dict -}}
{{- $ms.endpoint | default "http://minio.industrial-edge-ml-workspace.svc:9000" -}}
{{- end -}}

{{- define "neuroface.ppeEndpoint" -}}
{{- if .Values.neuroface.ppe.useFederatedGateway | default false -}}
http://neuroface-gateway-istio.neuroface-gateway-system.svc:8080
{{- else -}}
{{- .Values.neuroface.ppe.endpoint | default "http://yolo-ppe-serving:8080" -}}
{{- end -}}
{{- end -}}

{{- define "neuroface.maasApiKey" -}}
{{- $key := .Values.neuroface.chat.apiKey | default "" -}}
{{- if not $key -}}
{{- $lm := .Values.litemaas | default dict -}}
{{- $key = $lm.apiKey | default "" -}}
{{- end -}}
{{- $key -}}
{{- end -}}
