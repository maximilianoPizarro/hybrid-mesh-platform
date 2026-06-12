{{/*
  OpenAI-compatible base URL for Llama Stack vLLM provider (strip /v1/chat/completions).
*/}}
{{- define "developer-hub.vllmBaseUrl" -}}
{{- $url := .apiURL | default "" -}}
{{- $url = regexReplaceAll "/chat/completions/?$" $url "" -}}
{{- if not (hasSuffix "/v1" $url) -}}
{{- $url = printf "%s/v1" (trimSuffix "/" $url) -}}
{{- end -}}
{{- $url -}}
{{- end -}}

{{- define "developer-hub.lightspeedEnabled" -}}
{{- if .Values.plugins.lightspeed.enabled -}}true{{- end -}}
{{- end -}}

{{- define "developer-hub.lightspeedAiModel" -}}
{{- $ls := .Values.plugins.lightspeed | default dict -}}
{{- $ai := $ls.aiModel | default dict -}}
{{- if not $ai.apiURL -}}
{{- $ai = mergeOverwrite (dict) (.Values.aiModel | default dict) $ai -}}
{{- end -}}
{{- $ai | toJson -}}
{{- end -}}
