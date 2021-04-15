#!/bin/sh

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
SBASE=${CEPH_OSD_SOCKET_BASE:-${CLUSTER}-osd}
SSUFFIX=${CEPH_SOCKET_SUFFIX:-asok}

COMMAND="${@:-liveness}"

function extract_state () {
    python3 -c 'import json; import sys; input = json.load(sys.stdin); print(input["state"]);' 2>/dev/null
}

function heath_check () {
  # Default: no sockets, not live.
  exit_code=1
  # Normally we only have one OSD per pod, so at most one socket will be found.
  local -r socks=$(ls $SOCKDIR/$SBASE.*.$SSUFFIX 2>/dev/null)
  if [[ -n $socks ]]; then
    for sock in $socks; do
      local -r current_state="$(ceph -f json-pretty --connect-timeout 1 --admin-daemon "${sock}" status | extract_state)"
      # This might be a stricter check than we actually want. What are the other values for the "state" field?
      # Another state I've seen is "booting".
      if [[ ${current_state} == active ]]; then
       exit_code=0
      else
       # One's not ready, so the whole pod's not ready.
       exit_code=1
       break
      fi
    done
  fi
  exit $exit_code
}

function liveness () {
  heath_check
}

function readiness () {
  heath_check
}

$COMMAND
