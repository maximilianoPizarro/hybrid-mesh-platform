{{- define "hub-post-install-bootstrap.enabled" -}}
{{- .Values.enabled | default true -}}
{{- end -}}

{{- define "hub-post-install-bootstrap.ns" -}}
{{- .Values.namespace | default "openshift-gitops" -}}
{{- end -}}

{{- define "hub-post-install-bootstrap.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{- define "hub-post-install-bootstrap.hookAnnotations" -}}
argocd.argoproj.io/hook: PostSync
argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
{{- end -}}

{{- define "hub-post-install-bootstrap.jobContainer" -}}
- name: bootstrap
  image: {{ include "hub-post-install-bootstrap.image" .root }}
  imagePullPolicy: {{ .root.Values.image.pullPolicy }}
  command: ["/bin/bash", {{ index .command 0 | quote }}]
  volumeMounts:
    - name: scripts
      mountPath: /scripts
  env:
    - name: GIT_REPO
      value: {{ .root.Values.git.repoUrl | quote }}
    - name: GIT_REVISION
      value: {{ .root.Values.git.revision | quote }}
    - name: HELM_VERSION
      value: {{ .root.Values.helmVersion | quote }}
    {{- range .extraEnv }}
    - name: {{ .name }}
      value: {{ .value | quote }}
    {{- end }}
{{- end -}}
