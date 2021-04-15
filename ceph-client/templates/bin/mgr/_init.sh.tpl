#!/bin/bash

{{/*
Copyright 2018 The Openstack-Helm Authors.

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

set -ex
export LC_ALL=C

: "${ADMIN_KEYRING:=/etc/ceph/${CLUSTER}.client.admin.keyring}"

if [[ ! -e /etc/ceph/${CLUSTER}.conf ]]; then
  echo "ERROR- /etc/ceph/${CLUSTER}.conf must exist; get it from your existing mon"
  exit 1
fi

if [[ ! -e ${ADMIN_KEYRING} ]]; then
   echo "ERROR- ${ADMIN_KEYRING} must exist; get it from your existing mon"
   exit 1
fi

ceph --cluster "${CLUSTER}" -v

MODULES_TO_DISABLE=`ceph mgr dump | python3 -c "import json, sys; print ' '.join(json.load(sys.stdin)['modules'])"`
{{- if .Values.conf.mgr.modules }}
  {{- range $value := .Values.conf.mgr.modules }}
    ceph --cluster "${CLUSTER}" mgr module enable  '{{ $value }}' --force
    MODULES_TO_DISABLE=${MODULES_TO_DISABLE/{{ $value }}/}
  {{- end }}
{{- end }}

for module in $MODULES_TO_DISABLE; do
  ceph --cluster "${CLUSTER}" mgr module disable "${module}"
done

{{- if .Values.conf.mgr.config }}
  {{- range $module, $params := .Values.conf.mgr.config }}
    {{- range $key, $value := $params }}
      ceph --cluster "${CLUSTER}" config set mgr 'mgr/{{ $module }}/{{ $key }}' '{{ $value }}' --force
    {{- end }}
  {{- end }}
{{- end }}

{{- if (has "dashboard" .Values.conf.mgr.modules) }}
ceph --cluster "${CLUSTER}" config set mgr mgr/dashboard/ssl false
ceph --cluster "${CLUSTER}" config set mgr mgr/dashboard/server_port {{ tuple "ceph_mgr" "internal" "dashboard" . | include "helm-toolkit.endpoints.endpoint_port_lookup" }}
# The following two don't work with <=14.2.4, so force them into the config db for later releases
ceph --cluster "${CLUSTER}" config set mgr mgr/dashboard/standby_behaviour error --force
ceph --cluster "${CLUSTER}" config set mgr mgr/dashboard/standby_error_status_code 503 --force

{{- if and .Values.conf.features.rgw .Values.conf.rgw_s3.enabled }}
ceph --cluster "${CLUSTER}" dashboard set-rgw-api-access-key '{{ .Values.conf.rgw_s3.auth.admin.access_key }}'
ceph --cluster "${CLUSTER}" dashboard set-rgw-api-secret-key '{{ .Values.conf.rgw_s3.auth.admin.secret_key }}'
ceph --cluster "${CLUSTER}" dashboard set-rgw-api-host ceph-rgw
ceph --cluster "${CLUSTER}" dashboard set-rgw-api-port '{{ tuple "ceph_object_store" "internal" "api" . | include "helm-toolkit.endpoints.endpoint_port_lookup" }}'
{{- end }}

{{- if .Values.conf.mgr.dashboard.users }}
  {{- range $user := .Values.conf.mgr.dashboard.users }}
    if ceph --cluster "${CLUSTER}" dashboard ac-user-show '{{ $user.username }}'; then
      ceph --cluster "${CLUSTER}" dashboard ac-user-set-password '{{ $user.username }}' '{{ $user.password }}'
      ceph --cluster "${CLUSTER}" dashboard ac-user-set-roles '{{ $user.username }}' '{{ $user.role }}'
    else
      ceph --cluster "${CLUSTER}" dashboard ac-user-create '{{ $user.username }}' '{{ $user.password }}' '{{ $user.role }}'
    fi
  {{- end }}
{{- end }}

DASHBOARD_FEATURES_TO_DISABLE=$(ceph --cluster "${CLUSTER}" dashboard feature status | sed -e 's/Feature '"'"'\([^'"'"']\+\)'"'"'.\+/\1/')
{{- range $value := .Values.conf.mgr.dashboard.features }}
  ceph --cluster "${CLUSTER}" dashboard feature enable '{{ $value }}'
    DASHBOARD_FEATURES_TO_DISABLE=${DASHBOARD_FEATURES_TO_DISABLE/{{ $value }}/}
  {{- end }}
{{- end }}

for module in $DASHBOARD_FEATURES_TO_DISABLE; do
  ceph --cluster "${CLUSTER}" dashboard feature disable "${module}"
done

exit 0
# EOF

