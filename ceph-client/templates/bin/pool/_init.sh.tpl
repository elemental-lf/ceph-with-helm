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
: "${PG_NUM_MIN:=32}"

if [[ ! -e /etc/ceph/${CLUSTER}.conf ]]; then
  echo "ERROR- /etc/ceph/${CLUSTER}.conf must exist; get it from your existing mon"
  exit 1
fi

if [[ ! -e ${ADMIN_KEYRING} ]]; then
   echo "ERROR- ${ADMIN_KEYRING} must exist; get it from your existing mon"
   exit 1
fi

if ! ceph --cluster "${CLUSTER}" osd crush rule ls | grep -q "^same_host$"; then
  ceph --cluster "${CLUSTER}" osd crush rule create-simple same_host default osd
fi

# Ensure standard device classes exist and create replicated rules for them
for class in hdd ssd nvme; do
  # "ceph osd crush class create" also returns success if the class already exists
  ceph --cluster "${CLUSTER}" osd crush class create ${class}

  if ! ceph --cluster "${CLUSTER}" osd crush rule ls | grep -q "^replicated_rule_${class}$"; then
    # We ignore errors as there might not be any devices of a specific class present at all.
    ceph --cluster "${CLUSTER}" osd crush rule create-replicated replicated_rule_${class} default host ${class} || true
  fi
done

function create_pool () {
  POOL_APPLICATION="$1"
  POOL_NAME="$2"
  POOL_REPLICATION="$3"
  TOTAL_DATA_PERCENT="$4"
  POOL_CRUSH_RULE="$5"
  POOL_EC_PROFILE_SPEC="$6"

  if ! ceph --cluster "${CLUSTER}" osd pool stats "${POOL_NAME}" > /dev/null 2>&1; then
    if [ -z "$POOL_EC_PROFILE_SPEC" ]; then
      ceph --cluster "${CLUSTER}" osd pool create --pg-num-min "${PG_NUM_MIN}" "${POOL_NAME}" ${POOL_PLACEMENT_GROUPS}
    else
      if ! ceph --cluster "${CLUSTER}" osd erasure-code-profile ls | grep -q "^${POOL_NAME}$"; then
        ceph --cluster "${CLUSTER}" osd erasure-code-profile set "${POOL_NAME}" $POOL_EC_PROFILE_SPEC
      fi
      # This will also implicitly create the corresponding crush rule (named after the pool, too)
      ceph --cluster "${CLUSTER}" osd pool create --pg-num-min "${PG_NUM_MIN}" "${POOL_NAME}" ${POOL_PLACEMENT_GROUPS} ${POOL_PLACEMENT_GROUPS} erasure ${POOL_NAME}
    fi
    while [ $(ceph --cluster "${CLUSTER}" -s | grep creating -c) -gt 0 ]; do echo -n .;sleep 1; done
    if [ "x${POOL_APPLICATION}" == "xrbd" ]; then
      rbd --cluster "${CLUSTER}" pool init ${POOL_NAME}
    fi
    ceph --cluster "${CLUSTER}" osd pool application enable "${POOL_NAME}" "${POOL_APPLICATION}"
  fi

  # Only do this for replicated pools
  if [ -z "$POOL_EC_PROFILE_SPEC" ]; then
    ceph --cluster "${CLUSTER}" osd pool set "${POOL_NAME}" size ${POOL_REPLICATION}
    ceph --cluster "${CLUSTER}" osd pool set "${POOL_NAME}" crush_rule "${POOL_CRUSH_RULE}"
  fi

  ceph --cluster "${CLUSTER}" osd pool set "${POOL_NAME}" target_size_ratio "${TOTAL_DATA_PERCENT}"
}

function wait_for_inactive_pgs () {
  # Loop until all pgs are active
  while [[ `ceph --cluster ${CLUSTER} pg ls | grep '^[[:digit:]]' | grep -v "active+"` ]]
  do
    sleep 3
  done
}

{{ $crushRuleDefault := .Values.conf.pool.default.crush_rule }}
{{- range $pool := .Values.conf.pool.spec -}}
{{- with $pool }}
create_pool '{{ .application }}' '{{ .name }}' '{{ .replication }}' '{{ .percent_total_data }}' '{{ .crush_rule | default $crushRuleDefault }}' '{{ .ec_profile_spec | default "" }}'
{{- end }}
{{- end }}

{{- if .Values.conf.pool.crush.tunables }}
ceph --cluster "${CLUSTER}" osd crush tunables {{ .Values.conf.pool.crush.tunables }}
{{- end }}

wait_for_inactive_pgs
