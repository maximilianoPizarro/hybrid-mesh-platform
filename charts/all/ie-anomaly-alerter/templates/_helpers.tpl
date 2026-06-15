{{- define "ie-anomaly-alerter.hubClusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.hubClusterDomain | default $g.hubClusterDomain | default "" -}}
{{- end -}}

{{- define "ie-anomaly-alerter.mailpitUrl" -}}
{{- if .Values.mailpit.url -}}
{{- .Values.mailpit.url -}}
{{- else -}}
{{- $hub := include "ie-anomaly-alerter.hubClusterDomain" . -}}
{{- if eq $hub "" -}}
INVALID-HUB-DOMAIN
{{- else -}}
{{- printf "https://mailpit.%s/api/v1/send" $hub -}}
{{- end -}}
{{- end -}}
{{- end -}}
