{{- define "gitlab-operator.clusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.clusterDomain | default $g.localClusterDomain | default $g.hubClusterDomain | default "apps.cluster.example.com" -}}
{{- end -}}

{{- define "gitlab-operator.host" -}}
{{- printf "gitlab.apps.%s" (include "gitlab-operator.clusterDomain" .) -}}
{{- end -}}

{{- define "gitlab-operator.apiUrl" -}}
{{- printf "https://%s/api/v4" (include "gitlab-operator.host" .) -}}
{{- end -}}

{{- define "gitlab-operator.webUrl" -}}
{{- printf "https://%s" (include "gitlab-operator.host" .) -}}
{{- end -}}
