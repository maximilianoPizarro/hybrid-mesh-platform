{{- define "vault-maas-external-secrets.vaultMaasDataPath" -}}
{{- printf "secret/data/%s" (.Values.vault.maasPath | default "workshop/maas") -}}
{{- end -}}

{{- define "vault-maas-external-secrets.enabled" -}}
{{- .Values.enabled | default true -}}
{{- end -}}

{{- define "vault-maas-external-secrets.litemaasApiKey" -}}
{{- $lm := .Values.litemaas | default dict -}}
{{- $lm.apiKey | default "" -}}
{{- end -}}

{{- define "vault-maas-external-secrets.maasApiBase" -}}
{{- $lm := .Values.litemaas | default dict -}}
{{- $lm.apiUrl | default .Values.maas.openAiApiBase | default "https://maas-rhdp.apps.maas.redhatworkshops.io/v1" -}}
{{- end -}}

{{- define "vault-maas-external-secrets.rhdpSeedSyncEnabled" -}}
{{- and (include "vault-maas-external-secrets.enabled" .) (.Values.rhdpSeedSync.enabled | default true) -}}
{{- end -}}
