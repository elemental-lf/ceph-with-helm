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
SBASE=${CEPH_OSD_SOCKET_BASE:-${CLUSTER}-mgr}
SSUFFIX=${CEPH_SOCKET_SUFFIX:-asok}

COMMAND="${@:-liveness}"

function extract_osd_epoch () {
    python -c 'import json; import sys; input = json.load(sys.stdin); print(input["osd_epoch"]);' 2>/dev/null
}

function heath_check () {
   local -r sock="$(ls $SOCKDIR/$SBASE.*.$SSUFFIX 2>/dev/null | head -1)"
   [[ -z $sock || ! -S $sock ]] && exit 1
   local -r current_osd_epoch="$(ceph -f json-pretty --connect-timeout 1 --admin-daemon "${sock}" status | extract_osd_epoch)"
   [[ -n ${current_osd_epoch} ]] && exit 0 || exit 1
}

function liveness () {
  heath_check
}

function readiness () {
  heath_check
}

$COMMAND
