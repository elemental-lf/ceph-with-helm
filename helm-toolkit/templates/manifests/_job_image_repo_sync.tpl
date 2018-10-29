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

# This function creates a manifest for the image repo sync jobs.
# It can be used in charts dict created similar to the following:
# {- $imageRepoSyncJob := dict "envAll" . "serviceName" "prometheus" -}
# { $imageRepoSyncJob | include "helm-toolkit.manifests.job_image_repo_sync" }

{{- define "helm-toolkit.manifests.job_image_repo_sync" -}}
{{- $envAll := index . "envAll" -}}
{{- $serviceName := index . "serviceName" -}}
{{- $nodeSelector := index . "nodeSelector" | default ( dict $envAll.Values.labels.job.node_selector_key $envAll.Values.labels.job.node_selector_value ) -}}
{{- $podVolMounts := index . "podVolMounts" | default false -}}
{{- $podVols := index . "podVols" | default false -}}
{{- $configMapBin := index . "configMapBin" | default (printf "%s-%s" $serviceName "bin" ) -}}

{{- $serviceNamePretty := $serviceName | replace "_" "-" -}}

{{- $serviceAccountName := printf "%s-%s" $serviceNamePretty "image-repo-sync" }}
{{ tuple $envAll "image_repo_sync" $serviceAccountName | include "helm-toolkit.snippets.kubernetes_pod_rbac_serviceaccount" }}
---
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ printf "%s-%s" $serviceNamePretty "image-repo-sync" | quote }}
spec:
  template:
    metadata:
      labels:
{{ tuple $envAll $serviceName "image-repo-sync" | include "helm-toolkit.snippets.kubernetes_metadata_labels" | indent 8 }}
    spec:
      serviceAccountName: {{ $serviceAccountName }}
      restartPolicy: OnFailure
      nodeSelector:
{{ toYaml $nodeSelector | indent 8 }}
      initContainers:
{{ tuple $envAll "image_repo_sync" list | include "helm-toolkit.snippets.kubernetes_entrypoint_init_container"  | indent 8 }}
      containers:
        - name: image-repo-sync
{{ tuple $envAll "image_repo_sync" | include "helm-toolkit.snippets.image" | indent 10 }}
{{ tuple $envAll $envAll.Values.pod.resources.jobs.image_repo_sync | include "helm-toolkit.snippets.kubernetes_resources" | indent 10 }}
          env:
            - name: LOCAL_REPO
              value: "{{ tuple "local_image_registry" "node" $envAll | include "helm-toolkit.endpoints.hostname_short_endpoint_lookup" }}:{{ tuple "local_image_registry" "node" "registry" $envAll | include "helm-toolkit.endpoints.endpoint_port_lookup" }}"
            - name: IMAGE_SYNC_LIST
              value: "{{ include "helm-toolkit.utils.image_sync_list" $envAll }}"
          command:
            - /tmp/image-repo-sync.sh
          volumeMounts:
            - name: bootstrap-sh
              mountPath: /tmp/image-repo-sync.sh
              subPath: image-repo-sync.sh
              readOnly: true
            - name: docker-socket
              mountPath: /var/run/docker.sock
{{- if $podVolMounts }}
{{ $podVolMounts | toYaml | indent 12 }}
{{- end }}
      volumes:
        - name: bootstrap-sh
          configMap:
            name: {{ $configMapBin | quote }}
            defaultMode: 0555
        - name: docker-socket
          hostPath:
            path: /var/run/docker.sock
{{- if $podVols }}
{{ $podVols | toYaml | indent 8 }}
{{- end }}
{{- end }}
