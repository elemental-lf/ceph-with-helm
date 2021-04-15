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
  python3 -c 'import json; import sys; input = json.load(sys.stdin); print(input[list(input.keys())[0]][0]["tags"]["ceph.osd_id"]);'
}

function extract_osd_fsid {
  python3 -c 'import json; import sys; input = json.load(sys.stdin); print(input[list(input.keys())[0]][0]["tags"]["ceph.osd_fsid"]);'
}

function extract_osd_lv_name {
  python3 -c 'import json; import sys; input = json.load(sys.stdin); print(input[list(input.keys())[0]][0]["lv_name"]);'
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

# ensure that all LVM2 symbolic links are present
vgscan --mknodes

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

# Starting with Nautilus Ceph implements flock on the logical volume to avoid data corruption
# when ceph-osd processes in two separate containers try to access the same data.
# See: https://tracker.ceph.com/issues/38150, https://github.com/ceph/ceph/pull/26245.
# There are backporting tickets for Mimic and Luminous, but they haven't been acted on since February 2019. (03.04.2020)
if ceph -v | egrep -q 'mimic|luminous'; then
  echo 'ERROR- Nautilus or above are required, otherwise data corruption will ensue.'
  exit 1
fi

# Also look at the corresponding code in _stop.sh.tpl.
exec ceph-osd \
    --cluster "${CLUSTER}" \
    -f \
    -i "${OSD_ID}" \
    --setuser ceph \
    --setgroup disk & echo $! > /run/ceph-osd.pid

wait
