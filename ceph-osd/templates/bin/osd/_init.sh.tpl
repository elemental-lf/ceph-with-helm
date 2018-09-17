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

: "${OSD_BOOTSTRAP_KEYRING:=/var/lib/ceph/bootstrap-osd/${CLUSTER}.keyring}"
: "${OSD_FORCE_ZAP:=0}"

function extract_cluster_fsid {
  python -c 'import json; import sys; input = json.load(sys.stdin); print(input[input.keys()[0]][0]["tags"]["ceph.cluster_fsid"]);'
}

OSD_DEVICE="$(readlink -f ${OSD_DEVICE})"
if [ -n "${OSD_DB_DEVICE}" ]; then
  OSD_DB_DEVICE="$(readlink -f ${OSD_DB_DEVICE})"
fi

if [ -z "${OSD_DEVICE}" ];then
  echo "ERROR- You must provide a device to build your OSD ie: /dev/sdb"
  exit 1
fi

if [ ! -b "${OSD_DEVICE}" ]; then
  echo "ERROR- The device pointed by OSD_DEVICE ($OSD_DEVICE) doesn't exist!"
  exit 1
fi

if [ ! -e "$OSD_BOOTSTRAP_KEYRING" ]; then
  echo "ERROR- $OSD_BOOTSTRAP_KEYRING must exist. You can extract it from your current monitor by running 'ceph auth get client.bootstrap-osd -o $OSD_BOOTSTRAP_KEYRING'"
  exit 1
fi
timeout 10 ceph ${CLI_OPTS} --name client.bootstrap-osd --keyring $OSD_BOOTSTRAP_KEYRING health || exit 1

CEPH_VOLUME_LVM_LIST="$(ceph-volume lvm list --format json "${OSD_DEVICE}")"
if [[ -n "${CEPH_VOLUME_LVM_LIST}" ]]; then
  DISK_CLUSTER_FSID="$(echo ${CEPH_VOLUME_LVM_LIST} | extract_cluster_fsid)"
  CLUSTER_FSID="$(ceph-conf --lookup fsid)"
  if [ "${DISK_CLUSTER_FSID}" != "${CLUSTER_FSID}" ]; then
    echo "It looks like ${OSD_DEVICE} is an OSD belonging to a different (or old) ceph cluster."
    echo "The OSD FSID is ${DISK_CLUSTER_FSID} while this cluster is ${CLUSTER_FSID}."
  
    if [ "${OSD_FORCE_ZAP}" -eq 1 ]; then
      echo "Because OSD_FORCE_ZAP was set, we will zap this device."
      ceph-volume lvm zap --destroy "${OSD_DEVICE}"
    else
      echo "Moving on, trying to activate the OSD now."
      exit 0
    fi
  else
    echo "Device ${OSD_DEVICE} is part of our cluster, trying to activate the OSD now."
    exit 0
  fi
else
  echo "Device ${OSD_DEVICE} will be prepared now."
fi
  
if [ -n "$OSD_DB_DEVICE" ]; then
  CLI_OPTS="${CLI_OPTS} --block.db ${OSD_DB_DEVICE}"
fi

ceph-volume lvm prepare --bluestore --no-systemd ${CLI_OPTS} --data "${OSD_DEVICE}"

# watch the udev event queue, and exit if all current events are handled
udevadm settle --timeout=600
