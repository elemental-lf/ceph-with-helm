#!/bin/bash

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

set -ex
export LC_ALL=C

SOCKDIR=${CEPH_SOCKET_DIR:-/run/ceph}
SBASE=${CEPH_OSD_SOCKET_BASE:-${CLUSTER}-mon}
SSUFFIX=${CEPH_SOCKET_SUFFIX:-asok}

COMMAND="${@:-liveness}"

function extract_state () {
    python3 -c 'import json; import sys; input = json.load(sys.stdin); print(input["state"]);' 2>/dev/null
}

function heath_check () {
  local -r mon_live_states="$1"
  local -r sock="$SOCKDIR/$SBASE.$NODE_NAME.$SSUFFIX"
  [[ ! -S $sock ]] && exit 1

  local -r current_state=$(ceph -f json-pretty --connect-timeout 1 --admin-daemon "$sock" mon_status | extract_state)
  [[ -z ${current_state} ]] && exit 1

  exit_code=1
  # This might be a stricter check than we actually want. What are the other values for the "state" field?
  for state in ${mon_live_states}; do
    if [[ ${current_state} == ${state} ]]; then
      exit_code=0
      break
    fi
  done

  exit $exit_code
}

function liveness () {
  heath_check "probing electing synchronizing leader peon"
}

function readiness () {
  heath_check "leader peon"
}

$COMMAND
