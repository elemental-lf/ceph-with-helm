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

COMMAND="${@:-liveness}"

function extract_osd_epoch () {
    python -c 'import json; import sys; input = json.load(sys.stdin); print(input["osd_epoch"]);' 2>/dev/null
}

function liveness () {
   local -r current_osd_epoch="$(ceph --cluster "${CLUSTER}" daemon mgr.$(hostname) --connect-timeout 1 -f json status | extract_osd_epoch)"
   [[ -n ${current_osd_epoch} ]] && exit 0 || exit 1
}

function readiness () {
  local -r active_mgr="$(timeout 10 ceph --cluster "${CLUSTER}" mgr dump -f json | jq -r .active_name)"
  [[ $active_mgr == $(hostname) ]] && exit 0 || exit 1
}

$COMMAND
