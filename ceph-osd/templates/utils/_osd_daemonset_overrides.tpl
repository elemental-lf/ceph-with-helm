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

{{- define "ceph.utils.match_exprs_hash" }}
  {{- $match_exprs := index . 0 }}
  {{- $context := index . 1 }}
  {{- $_ := set $context.Values "__match_exprs_hash_content" "" }}
  {{- range $match_expr := $match_exprs }}
    {{- $_ := set $context.Values "__match_exprs_hash_content" (print $context.Values.__match_exprs_hash_content $match_expr.key $match_expr.operator ($match_expr.values | quote)) }}
  {{- end }}
  {{- $context.Values.__match_exprs_hash_content | sha256sum | trunc 8 }}
  {{- $_ := unset $context.Values "__match_exprs_hash_content" }}
{{- end }}

{{- define "ceph.utils.osd_daemonset_list" }}
  {{- $daemonset_yaml := index . 0 }}
  {{- $configmap_name := index . 1 }}
  {{- $context := index . 2 }}
  {{- $_ := set $context.Values "__daemonset_yaml" $daemonset_yaml }}
  {{- $_ := set $context.Values "__daemonset_list" list }}
  {{- if hasKey $context.Values.conf "overrides" }}
    {{- range $key, $val := $context.Values.conf.overrides }}

      {{- if eq $key "ceph_osd" }}
        {{- range $type, $type_data := . }}

          {{- if eq $type "hosts" }}
            {{- range $host_data := . }}
              {{/* dictionary that will contain all info needed to generate this
              iteration of the daemonset */}}
              {{- $current_dict := dict }}

              {{/* set daemonset name */}}
              {{- $_ := set $current_dict "name" $host_data.name }}

              {{/* apply overrides */}}
              {{- $override_conf_copy := $host_data.conf }}
              {{- $root_conf_copy := omit $context.Values.conf "overrides" }}
              {{- $merged_dict := merge $override_conf_copy $root_conf_copy }}
              {{- $root_conf_copy2 := dict "conf" $merged_dict }}
              {{- $context_values := omit $context.Values "conf" }}
              {{- $root_conf_copy3 := merge $context_values $root_conf_copy2 }}
              {{- $root_conf_copy4 := dict "Values" $root_conf_copy3 }}
              {{- $_ := set $current_dict "nodeData" $root_conf_copy4 }}

              {{/* Schedule to this host explicitly. */}}
              {{- $nodeSelector_dict := dict }}

              {{- $_ := set $nodeSelector_dict "key" "kubernetes.io/hostname" }}
              {{- $_ := set $nodeSelector_dict "operator" "In" }}

              {{- $values_list := list $host_data.name }}
              {{- $_ := set $nodeSelector_dict "values" $values_list }}

              {{- $list_aggregate := list $nodeSelector_dict }}
              {{- $_ := set $current_dict "matchExpressions" $list_aggregate }}

              {{/* store completed daemonset entry/info into global list */}}
              {{- $list_aggregate := append $context.Values.__daemonset_list $current_dict }}
              {{- $_ := set $context.Values "__daemonset_list" $list_aggregate }}

            {{- end }}
          {{- end }}

          {{- if eq $type "labels" }}
            {{- $_ := set $context.Values "__label_list" . }}
            {{- range $label_data := . }}
              {{/* dictionary that will contain all info needed to generate this
              iteration of the daemonset. */}}
              {{- $_ := set $context.Values "__current_label" dict }}

              {{/* set daemonset name */}}
              {{- $_ := set $context.Values.__current_label "name" $label_data.label.key }}

              {{/* apply overrides */}}
              {{- $override_conf_copy := $label_data.conf }}
              {{- $root_conf_copy := omit $context.Values.conf "overrides" }}
              {{- $merged_dict := merge $override_conf_copy $root_conf_copy }}
              {{- $root_conf_copy2 := dict "conf" $merged_dict }}
              {{- $context_values := omit $context.Values "conf" }}
              {{- $root_conf_copy3 := merge $context_values $root_conf_copy2 }}
              {{- $root_conf_copy4 := dict "Values" $root_conf_copy3 }}
              {{- $_ := set $context.Values.__current_label "nodeData" $root_conf_copy4 }}

              {{/* Schedule to the provided label value(s) */}}
              {{- $label_dict := omit $label_data.label "NULL" }}
              {{- $_ := set $label_dict "operator" "In" }}
              {{- $list_aggregate := list $label_dict }}
              {{- $_ := set $context.Values.__current_label "matchExpressions" $list_aggregate }}

              {{/* Do not schedule to other specified labels, with higher
              precedence as the list position increases. Last defined label
              is highest priority. */}}
              {{- $other_labels := without $context.Values.__label_list $label_data }}
              {{- range $label_data2 := $other_labels }}
                {{- $label_dict := omit $label_data2.label "NULL" }}

                {{- $_ := set $label_dict "operator" "NotIn" }}

                {{- $list_aggregate := append $context.Values.__current_label.matchExpressions $label_dict }}
                {{- $_ := set $context.Values.__current_label "matchExpressions" $list_aggregate }}
              {{- end }}
              {{- $_ := set $context.Values "__label_list" $other_labels }}

              {{/* Do not schedule to any other specified hosts */}}
              {{- range $type, $type_data := $val }}
                {{- if eq $type "hosts" }}
                  {{- range $host_data := . }}
                    {{- $label_dict := dict }}

                    {{- $_ := set $label_dict "key" "kubernetes.io/hostname" }}
                    {{- $_ := set $label_dict "operator" "NotIn" }}

                    {{- $values_list := list $host_data.name }}
                    {{- $_ := set $label_dict "values" $values_list }}

                    {{- $list_aggregate := append $context.Values.__current_label.matchExpressions $label_dict }}
                    {{- $_ := set $context.Values.__current_label "matchExpressions" $list_aggregate }}
                  {{- end }}
                {{- end }}
              {{- end }}

              {{/* store completed daemonset entry/info into global list */}}
              {{- $list_aggregate := append $context.Values.__daemonset_list $context.Values.__current_label }}
              {{- $_ := set $context.Values "__daemonset_list" $list_aggregate }}
              {{- $_ := unset $context.Values "__current_label" }}

            {{- end }}
          {{- end }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}

  {{- range $current_dict := $context.Values.__daemonset_list }}

    {{- $context_novalues := omit $context "Values" }}
    {{- $merged_dict := merge $current_dict.nodeData $context_novalues }}
    {{- $_ := set $current_dict "nodeData" $merged_dict }}

    {{/* name needs to be a DNS-1123 compliant name. Ensure lower case */}}
    {{- $name_format1 := printf (print "ceph-osd-" $current_dict.name) | lower }}
    {{/* labels may contain underscores which would be invalid here, so we replace them with dashes
    there may be other valid label names which would make for an invalid DNS-1123 name
    but these will be easier to handle in future with sprig regex* functions
    (not availabile in helm 2.5.1) */}}
    {{- $name_format2 := $name_format1 | replace "_" "-" | replace "." "-" }}
    {{/* To account for the case where the same label is defined multiple times in overrides
    (but with different label values), we add a sha of the scheduling data to ensure
    name uniqueness */}}
    {{- $_ := set $current_dict "dns_1123_name" dict }}
    {{- if hasKey $current_dict "matchExpressions" }}
      {{- $_ := set $current_dict "dns_1123_name" (printf (print $name_format2 "-" (list $current_dict.matchExpressions $context | include "ceph.utils.match_exprs_hash"))) }}
    {{- else }}
      {{- $_ := set $current_dict "dns_1123_name" $name_format2 }}
    {{- end }}

    {{/* set daemonset metadata name */}}
    {{- if not $context.Values.__daemonset_yaml.metadata }}{{- $_ := set $context.Values.__daemonset_yaml "metadata" dict }}{{- end }}
    {{- if not $context.Values.__daemonset_yaml.metadata.name }}{{- $_ := set $context.Values.__daemonset_yaml.metadata "name" dict }}{{- end }}
    {{- $_ := set $context.Values.__daemonset_yaml.metadata "name" $current_dict.dns_1123_name }}

    {{/* set container names and add to the list of containers for the pod */}}
    {{- $_ := set $context.Values "__containers_list" ( list ) }}
    {{- range $container := $context.Values.__daemonset_yaml.spec.template.spec.containers }}
    {{- if eq $container.name "osd-pod" }}
    {{- $_ := set $container "name" $current_dict.dns_1123_name }}
    {{- end }}
    {{- $__containers_list := append $context.Values.__containers_list $container }}
    {{- $_ := set $context.Values "__containers_list" $__containers_list }}
    {{- end }}
    {{- $_ := set $context.Values.__daemonset_yaml.spec.template.spec "containers" $context.Values.__containers_list }}

    {{/* populate scheduling restrictions */}}
    {{- if hasKey $current_dict "matchExpressions" }}
      {{- if not $context.Values.__daemonset_yaml.spec.template.spec }}{{- $_ := set $context.Values.__daemonset_yaml.spec.template "spec" dict }}{{- end }}
      {{- if not $context.Values.__daemonset_yaml.spec.template.spec.affinity }}{{- $_ := set $context.Values.__daemonset_yaml.spec.template.spec "affinity" dict }}{{- end }}
      {{- if not $context.Values.__daemonset_yaml.spec.template.spec.affinity.nodeAffinity }}{{- $_ := set $context.Values.__daemonset_yaml.spec.template.spec.affinity "nodeAffinity" dict }}{{- end }}
      {{- if not $context.Values.__daemonset_yaml.spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution }}{{- $_ := set $context.Values.__daemonset_yaml.spec.template.spec.affinity.nodeAffinity "requiredDuringSchedulingIgnoredDuringExecution" dict }}{{- end }}
      {{- $match_exprs := dict }}
      {{- $_ := set $match_exprs "matchExpressions" $current_dict.matchExpressions }}
      {{- $appended_match_expr := list $match_exprs }}
      {{- $_ := set $context.Values.__daemonset_yaml.spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution "nodeSelectorTerms" $appended_match_expr }}
    {{- end }}

    {{/* input value hash for current set of values overrides */}}
    {{- if not $context.Values.__daemonset_yaml.spec }}{{- $_ := set $context.Values.__daemonset_yaml "spec" dict }}{{- end }}
    {{- if not $context.Values.__daemonset_yaml.spec.template }}{{- $_ := set $context.Values.__daemonset_yaml.spec "template" dict }}{{- end }}
    {{- if not $context.Values.__daemonset_yaml.spec.template.metadata }}{{- $_ := set $context.Values.__daemonset_yaml.spec.template "metadata" dict }}{{- end }}
    {{- if not $context.Values.__daemonset_yaml.spec.template.metadata.annotations }}{{- $_ := set $context.Values.__daemonset_yaml.spec.template.metadata "annotations" dict }}{{- end }}

    {{/* generate daemonset yaml */}}
{{ range $k, $v := index $current_dict.nodeData.Values.conf.storage "osd" }}
---
{{- $_ := set $context.Values "__tmpYAML" dict }}

{{ $dsNodeName := index $context.Values.__daemonset_yaml.metadata "name" }}
{{ $localDsNodeName := print (trunc 54 $current_dict.dns_1123_name) "-" (print $dsNodeName $k | quote | sha256sum | trunc 8)}}
{{- if not $context.Values.__tmpYAML.metadata }}{{- $_ := set $context.Values.__tmpYAML "metadata" dict }}{{- end }}
{{- $_ := set $context.Values.__tmpYAML.metadata "name" $localDsNodeName }}

  {{- if not $context.Values.__tmpYAML.spec }}{{- $_ := set $context.Values.__tmpYAML "spec" dict }}{{- end }}
  {{- if not $context.Values.__tmpYAML.spec.template }}{{- $_ := set $context.Values.__tmpYAML.spec "template" dict }}{{- end }}
  {{- if not $context.Values.__tmpYAML.spec.template.spec }}{{- $_ := set $context.Values.__tmpYAML.spec.template "spec" dict }}{{- end }}
  {{- if not $context.Values.__tmpYAML.spec.template.spec.containers }}{{- $_ := set $context.Values.__tmpYAML.spec.template.spec "containers" list }}{{- end }}
  {{- if not $context.Values.__tmpYAML.spec.template.spec.initContainers }}{{- $_ := set $context.Values.__tmpYAML.spec.template.spec "initContainers" list }}{{- end }}

  {{/* Set volumes */}}
  {{- $_ := set $context.Values.__tmpYAML.spec.template.spec "volumes" $context.Values.__daemonset_yaml.spec.template.spec.volumes }}

  {{/* Add environment variables to containers */}}
  {{- $_ := set $context.Values "__tmpYAMLcontainers" list }}
  {{- range $podContainer := $context.Values.__daemonset_yaml.spec.template.spec.containers }}
    {{- $_ := set $context.Values "_tmpYAMLcontainer" $podContainer }}
    {{- if empty $context.Values._tmpYAMLcontainer.env }}
    {{- $_ := set $context.Values._tmpYAMLcontainer "env" ( list ) }}
    {{- end }}
    {{ $containerEnv := prepend (prepend (prepend (index $context.Values._tmpYAMLcontainer "env") (dict "name" "OSD_DEVICE" "value" $v.data)) (dict "name" "OSD_FORCE_ZAP" "value" ($v.zap | default false | ternary "1" "0"))) (dict "name" "OSD_DB_DEVICE" "value" ($v.db | default "")) }}
    {{- $localInitContainerEnv := omit $context.Values._tmpYAMLcontainer "env" }}
    {{- $_ := set $localInitContainerEnv "env" $containerEnv }}
    {{ $containerList := append $context.Values.__tmpYAMLcontainers $localInitContainerEnv }}
    {{ $_ := set $context.Values "__tmpYAMLcontainers" $containerList }}
  {{ end }}
  {{- $_ := set $context.Values.__tmpYAML.spec.template.spec "containers" $context.Values.__tmpYAMLcontainers }}

  {{/* Add environment variables to initContainers */}}
  {{- $_ := set $context.Values "__tmpYAMLinitContainers" list }}
  {{- range $podContainer := $context.Values.__daemonset_yaml.spec.template.spec.initContainers }}
    {{- $_ := set $context.Values "_tmpYAMLinitContainer" $podContainer }}
    {{ $initContainerEnv := prepend (prepend (prepend (index $context.Values._tmpYAMLinitContainer "env") (dict "name" "OSD_DEVICE" "value" $v.data)) (dict "name" "OSD_FORCE_ZAP" "value" ($v.zap | default false | ternary "1" "0"))) (dict "name" "OSD_DB_DEVICE" "value" ($v.db | default "")) }}
    {{- $localInitContainerEnv := omit $context.Values._tmpYAMLinitContainer "env" }}
    {{- $_ := set $localInitContainerEnv "env" $initContainerEnv }}
    {{ $initContainerList := append $context.Values.__tmpYAMLinitContainers $localInitContainerEnv }}
    {{ $_ := set $context.Values "__tmpYAMLinitContainers" $initContainerList }}
  {{ end }}
  {{- $_ := set $context.Values.__tmpYAML.spec.template.spec "initContainers" $context.Values.__tmpYAMLinitContainers }}

{{ merge $context.Values.__tmpYAML $context.Values.__daemonset_yaml | toYaml }}

{{ end }}

---
  {{- end }}
{{- end }}
