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

# This function creates a manifest for db creation and user management.
# It can be used in charts dict created similar to the following:
# {- $bootstrapJob := dict "envAll" . "serviceName" "senlin" -}
# { $bootstrapJob | include "helm-toolkit.manifests.job_bootstrap" }

{{- define "helm-toolkit.manifests.job_bootstrap" -}}
{{- $envAll := index . "envAll" -}}
{{- $serviceName := index . "serviceName" -}}
{{- $nodeSelector := index . "nodeSelector" | default ( dict $envAll.Values.labels.job.node_selector_key $envAll.Values.labels.job.node_selector_value ) -}}
{{- $podVolMounts := index . "podVolMounts" | default false -}}
{{- $podVols := index . "podVols" | default false -}}
{{- $configMapBin := index . "configMapBin" | default (printf "%s-%s" $serviceName "bin" ) -}}
{{- $configMapEtc := index . "configMapEtc" | default (printf "%s-%s" $serviceName "etc" ) -}}
{{- $configFile := index . "configFile" | default (printf "/etc/%s/%s.conf" $serviceName $serviceName ) -}}
{{- $logConfigFile := index . "logConfigFile" | default (printf "/etc/%s/logging.conf" $serviceName ) -}}
{{- $keystoneUser := index . "keystoneUser" | default $serviceName -}}
{{- $openrc := index . "openrc" | default "true" -}}

{{- $serviceNamePretty := $serviceName | replace "_" "-" -}}

{{- $serviceAccountName := printf "%s-%s" $serviceNamePretty "bootstrap" }}
{{ tuple $envAll "bootstrap" $serviceAccountName | include "helm-toolkit.snippets.kubernetes_pod_rbac_serviceaccount" }}
---
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ printf "%s-%s" $serviceNamePretty "bootstrap" | quote }}
spec:
  template:
    metadata:
      labels:
{{ tuple $envAll $serviceName "bootstrap" | include "helm-toolkit.snippets.kubernetes_metadata_labels" | indent 8 }}
    spec:
      serviceAccountName: {{ $serviceAccountName }}
      restartPolicy: OnFailure
      nodeSelector:
{{ toYaml $nodeSelector | indent 8 }}
      initContainers:
{{ tuple $envAll "bootstrap" list | include "helm-toolkit.snippets.kubernetes_entrypoint_init_container"  | indent 8 }}
      containers:
        - name: bootstrap
          image: {{ $envAll.Values.images.tags.bootstrap }}
          imagePullPolicy: {{ $envAll.Values.images.pull_policy }}
{{ tuple $envAll $envAll.Values.pod.resources.jobs.bootstrap | include "helm-toolkit.snippets.kubernetes_resources" | indent 10 }}
{{- if eq $openrc "true" }}
          env:
{{- with $env := dict "ksUserSecret" ( index $envAll.Values.secrets.identity $keystoneUser ) }}
{{- include "helm-toolkit.snippets.keystone_openrc_env_vars" $env | indent 12 }}
{{- end }}
{{- end }}
          command:
            - /tmp/bootstrap.sh
          volumeMounts:
            - name: bootstrap-sh
              mountPath: /tmp/bootstrap.sh
              subPath: bootstrap.sh
              readOnly: true
            - name: etc-service
              mountPath: {{ dir $configFile | quote }}
            - name: bootstrap-conf
              mountPath: {{ $configFile | quote }}
              subPath: {{ base $configFile | quote }}
              readOnly: true
            - name: bootstrap-conf
              mountPath: {{ $logConfigFile | quote }}
              subPath: {{ base $logConfigFile | quote }}
              readOnly: true
{{- if $podVolMounts }}
{{ $podVolMounts | toYaml | indent 12 }}
{{- end }}
      volumes:
        - name: bootstrap-sh
          configMap:
            name: {{ $configMapBin | quote }}
            defaultMode: 0555
        - name: etc-service
          emptyDir: {}
        - name: bootstrap-conf
          secret:
            secretName: {{ $configMapEtc | quote }}
            defaultMode: 0444
{{- if $podVols }}
{{ $podVols | toYaml | indent 8 }}
{{- end }}
{{- end }}
