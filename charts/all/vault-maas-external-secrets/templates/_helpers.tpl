{{- define "vault-maas-external-secrets.vaultMaasDataPath" -}}
{{- printf "secret/data/%s" (.Values.vault.maasPath | default "workshop/maas") -}}
{{- end -}}

{{- define "vault-maas-external-secrets.enabled" -}}
{{- .Values.enabled | default true -}}
{{- end -}}
