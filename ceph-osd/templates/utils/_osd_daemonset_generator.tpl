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

{{- define "ceph.utils.osd_ds_name" }}
  {{- $host := index . 0 }}
  {{- $osd := index . 1 }}
  {{- (printf "ceph-osd-%s-%s" (regexReplaceAllLiteral "\\..+$" $host "" | lower) (regexReplaceAllLiteral "[^a-zA-Z0-9]" (regexReplaceAllLiteral "^.*/" $osd "") "-")) | trunc 63 }}
{{- end }}

{{- define "ceph.utils.osd_daemonset_generator" }}
  {{- $daemonset_yaml := index . 0 }}
  {{- $context := index . 1 }}

  {{- range $entry := $context.Values.conf.storage.osd }}
    {{- range $host := $entry.hosts }}
      {{- range $osd := $entry.osds }}
        {{/* Populate current DaemonSet */}}
        {{- $_ := set $context.Values "__daemonset_yaml" ($daemonset_yaml | fromYaml) }}
        {{- if not $context.Values.__daemonset_yaml.metadata }}{{- $_ := set $context.Values.__daemonset_yaml "metadata" dict }}{{- end }}
        {{- if not $context.Values.__daemonset_yaml.spec }}{{- $_ := set $context.Values.__daemonset_yaml "spec" dict }}{{- end }}
        {{- if not $context.Values.__daemonset_yaml.spec.template }}{{- $_ := set $context.Values.__daemonset_yaml.spec "template" dict }}{{- end }}
        {{- if not $context.Values.__daemonset_yaml.spec.template.spec }}{{- $_ := set $context.Values.__daemonset_yaml.spec.template "spec" dict }}{{- end }}
        {{- if not $context.Values.__daemonset_yaml.spec.template.spec.affinity }}{{- $_ := set $context.Values.__daemonset_yaml.spec.template.spec "affinity" dict }}{{- end }}
        {{- if not $context.Values.__daemonset_yaml.spec.template.spec.affinity.nodeAffinity }}{{- $_ := set $context.Values.__daemonset_yaml.spec.template.spec.affinity "nodeAffinity" dict }}{{- end }}
        {{- if not $context.Values.__daemonset_yaml.spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution }}{{- $_ := set $context.Values.__daemonset_yaml.spec.template.spec.affinity.nodeAffinity "requiredDuringSchedulingIgnoredDuringExecution" dict }}{{- end }}

        {{/* Set DaemonSet metadata name */}}
        {{- $_ := set $context.Values.__daemonset_yaml.metadata "name" (list $host $osd.data | include "ceph.utils.osd_ds_name") }}

        {{/* Build node selector */}}
        {{- $nodeSelector_dict := dict }}
        {{- $_ := set $nodeSelector_dict "key" "kubernetes.io/hostname" }}
        {{- $_ := set $nodeSelector_dict "operator" "In" }}
        {{- $_ := set $nodeSelector_dict "values" (list $host) }}

        {{- $match_exprs := dict }}
        {{- $_ := set $match_exprs "matchExpressions" (list $nodeSelector_dict) }}
        {{- $_ := set $context.Values.__daemonset_yaml.spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution "nodeSelectorTerms" (list $match_exprs) }}

        {{/* Add environment variables to containers and set their name */}}
        {{- $_ := set $context.Values "__tmpYAMLcontainers" list }}
        {{- range $podContainer := $context.Values.__daemonset_yaml.spec.template.spec.containers }}
          {{- $_ := set $context.Values "_tmpYAMLcontainer" $podContainer }}
          {{- if eq $podContainer.name "osd-pod" }}
            {{- $_ := set $podContainer "name" (list $host $osd.data | include "ceph.utils.osd_ds_name") }}
          {{- end }}

          {{- if empty $context.Values._tmpYAMLcontainer.env }}
            {{- $_ := set $context.Values._tmpYAMLcontainer "env" ( list ) }}
          {{- end }}
          {{ $containerEnv := prepend (prepend (prepend (index $context.Values._tmpYAMLcontainer "env") (dict "name" "OSD_DEVICE" "value" $osd.data)) (dict "name" "OSD_FORCE_ZAP" "value" ($osd.zap | default false | ternary "1" "0"))) (dict "name" "OSD_DB_DEVICE" "value" ($osd.db | default "")) }}
          {{- $localInitContainerEnv := omit $context.Values._tmpYAMLcontainer "env" }}
          {{- $_ := set $localInitContainerEnv "env" $containerEnv }}
          {{ $containerList := append $context.Values.__tmpYAMLcontainers $localInitContainerEnv }}
          {{ $_ := set $context.Values "__tmpYAMLcontainers" $containerList }}
        {{ end }}
        {{- $_ := set $context.Values.__daemonset_yaml.spec.template.spec "containers" $context.Values.__tmpYAMLcontainers }}

        {{/* Add environment variables to initContainers */}}
        {{- $_ := set $context.Values "__tmpYAMLinitContainers" list }}
        {{- range $podContainer := $context.Values.__daemonset_yaml.spec.template.spec.initContainers }}
          {{- $_ := set $context.Values "_tmpYAMLinitContainer" $podContainer }}
          {{ $initContainerEnv := prepend (prepend (prepend (index $context.Values._tmpYAMLinitContainer "env") (dict "name" "OSD_DEVICE" "value" $osd.data)) (dict "name" "OSD_FORCE_ZAP" "value" ($osd.zap | default false | ternary "1" "0"))) (dict "name" "OSD_DB_DEVICE" "value" ($osd.db | default "")) }}
          {{- $localInitContainerEnv := omit $context.Values._tmpYAMLinitContainer "env" }}
          {{- $_ := set $localInitContainerEnv "env" $initContainerEnv }}
          {{ $initContainerList := append $context.Values.__tmpYAMLinitContainers $localInitContainerEnv }}
          {{ $_ := set $context.Values "__tmpYAMLinitContainers" $initContainerList }}
        {{ end }}
        {{- $_ := set $context.Values.__daemonset_yaml.spec.template.spec "initContainers" $context.Values.__tmpYAMLinitContainers }}
---
{{ $context.Values.__daemonset_yaml | toYaml }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
