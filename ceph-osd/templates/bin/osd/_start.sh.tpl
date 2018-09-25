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
: "${CRUSH_LOCATION:=root=default host=${HOSTNAME}}"
: "${OSD_PATH_BASE:=/var/lib/ceph/osd/${CLUSTER}}"

OSD_DEVICE="$(readlink -e ${OSD_DEVICE})"

function extract_osd_id {
  python -c 'import json; import sys; input = json.load(sys.stdin); print(input[input.keys()[0]][0]["tags"]["ceph.osd_id"]);'
}

function extract_osd_fsid {
  python -c 'import json; import sys; input = json.load(sys.stdin); print(input[input.keys()[0]][0]["tags"]["ceph.osd_fsid"]);'
}

function extract_osd_lv_name {
  python -c 'import json; import sys; input = json.load(sys.stdin); print(input[input.keys()[0]][0]["lv_name"]);'
}

if [ ! -e "/etc/ceph/${CLUSTER}.conf" ]; then
  echo "ERROR- /etc/ceph/${CLUSTER}.conf must exist; get it from your existing mon"
  exit 1
fi

if [ -z "${OSD_DEVICE}" ]; then
  echo "ERROR- You must provide a device to build your OSD ie: /dev/sdb"
  exit 1
fi

if [ ! -b "${OSD_DEVICE}" ]; then
  echo "ERROR- The device pointed by OSD_DEVICE ($OSD_DEVICE) doesn't exist !"
  exit 1
fi

# watch the udev event queue, and exit if all current events are handled
udevadm settle --timeout=600

CEPH_VOLUME_LVM_LIST="$(ceph-volume lvm list --format json "${OSD_DEVICE}")"
if [[ -z ${CEPH_VOLUME_LVM_LIST} || ${CEPH_VOLUME_LVM_LIST} == "{}" ]]; then
  echo "ERROR- The device $OSD_DEVICE doesn't look like an OSD device."
  exit 1
fi
OSD_ID="$(echo ${CEPH_VOLUME_LVM_LIST} | extract_osd_id)"
OSD_FSID="$(echo ${CEPH_VOLUME_LVM_LIST} | extract_osd_fsid)"
OSD_LV_NAME="$(echo ${CEPH_VOLUME_LVM_LIST} | extract_osd_lv_name)"
# This sets LVM2_VG_NAME
eval $(lvs -o vg_name --noheadings -S "lv_name=${OSD_LV_NAME}" --nameprefixes)

if [ -z "${LVM2_VG_NAME}" ]; then
  echo "ERROR- Couldn't determine volume group name for $OSD_DEVICE."
  exit 1
fi

lvchange -ay "${LVM2_VG_NAME}/${OSD_LV_NAME}"
udevadm settle --timeout=600
ceph-volume lvm activate --bluestore --no-systemd "${OSD_ID}" "${OSD_FSID}"

OSD_PATH="${OSD_PATH_BASE}-${OSD_ID}"
OSD_KEYRING="${OSD_PATH}/keyring"
OSD_WEIGHT=$(awk "BEGIN { d= $(blockdev --getsize64 "${OSD_PATH}/block")/1099511627776 ; r = sprintf(\"%.2f\", d); print r }")

ceph \
  --cluster "${CLUSTER}" \
  --name="osd.${OSD_ID}" \
  --keyring="${OSD_KEYRING}" \
  osd \
  crush \
  create-or-move -- "${OSD_ID}" "${OSD_WEIGHT}" ${CRUSH_LOCATION}

# The flock prevents two ceph-osd processes from accessing the same
# OSD device. This may happen when pods are updated and the old and
# new version exist simultaneously.
# The recorded PID is actually the PID of the flock process.
exec flock --exclusive --timeout 15 \
    "/dev/${LVM2_VG_NAME}/${OSD_LV_NAME}" \
    ceph-osd \
    --cluster "${CLUSTER}" \
    -f \
    -i "${OSD_ID}" \
    --setuser ceph \
    --setgroup disk & echo $! > /run/ceph-osd.pid
wait
