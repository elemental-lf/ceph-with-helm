{{/*
Copyright 2017 The Openstack-Helm Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/}}

{{/*
abstract: |
  Renders kubernetes resource limits for pods
values: |
  pod:
    resources:
      enabled: true
      api:
        requests:
          memory: "128Mi"
          cpu: "100m"
        limits:
          memory: "1024Mi"
          cpu: "2000m"

usage: |
  {{ include "helm-toolkit.snippets.kubernetes_resources" ( tuple . .Values.pod.resources.api ) }}
return: |
  resources:
    limits:
      cpu: "2000m"
      memory: "1024Mi"
    requests:
      cpu: "100m"
      memory: "128Mi
*/}}

{{- define "helm-toolkit.snippets.kubernetes_resources" -}}
{{- $envAll := index . 0 -}}
{{- $component := index . 1 -}}
{{- if $envAll.Values.pod.resources.enabled -}}
resources:
  {{- if or $component.limits.cpu $component.limits.memory }}
  limits:
    {{- if $component.limits.cpu }}
    cpu: {{ $component.limits.cpu | quote }}
    {{- end }}
    {{- if $component.limits.memory }}
    memory: {{ $component.limits.memory | quote }}
    {{- end }}
  {{- end }}
  {{- if or $component.requests.cpu $component.requests.memory }}
  requests:
    {{- if $component.requests.cpu }}
    cpu: {{ $component.requests.cpu | quote }}
    {{- end }}
    {{- if $component.requests.memory }}
    memory: {{ $component.requests.memory | quote }}
    {{- end }}
  {{- end }}
{{- end -}}
{{- end -}}
