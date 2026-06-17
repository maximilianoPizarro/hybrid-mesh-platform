{{/*
  Resolve apps ingress domain from VP global values (RHDP deployer.domain) or explicit override.
*/}}
{{- define "acm-hub-spoke.clusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.clusterDomain | default $g.localClusterDomain | default $g.hubClusterDomain | default "apps.cluster.example.com" -}}
{{- end -}}

{{- define "acm-hub-spoke.hubClusterDomain" -}}
{{- $g := .Values.global | default dict -}}
{{- .Values.hubClusterDomain | default $g.hubClusterDomain | default (include "acm-hub-spoke.clusterDomain" .) -}}
{{- end -}}

{{- define "acm-hub-spoke.gitopsRepoUrl" -}}
{{- $g := .Values.global | default dict -}}
{{- $gitops := .Values.gitops | default dict -}}
{{- $gitops.repoUrl | default $gitops.repoURL | default $g.repoURL | default "https://github.com/maximilianoPizarro/hybrid-mesh-platform" -}}
{{- end -}}

{{- define "acm-hub-spoke.gitopsRevision" -}}
{{- $g := .Values.global | default dict -}}
{{- $gitops := .Values.gitops | default dict -}}
{{- $gitops.revision | default $g.targetRevision | default "main" -}}
{{- end -}}
