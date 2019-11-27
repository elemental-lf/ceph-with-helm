#!/bin/bash
set -ex
: "${CEPH_GET_ADMIN_KEY:=0}"
: "${MGR_NAME:=$(uname -n)}"
: "${MGR_KEYRING:=/var/lib/ceph/mgr/${CLUSTER}-${MGR_NAME}/keyring}"
: "${ADMIN_KEYRING:=/etc/ceph/${CLUSTER}.client.admin.keyring}"

if [[ ! -e /etc/ceph/${CLUSTER}.conf ]]; then
    echo "ERROR- /etc/ceph/${CLUSTER}.conf must exist; get it from your existing mon"
    exit 1
fi

if [ ${CEPH_GET_ADMIN_KEY} -eq 1 ]; then
    if [[ ! -e ${ADMIN_KEYRING} ]]; then
        echo "ERROR- ${ADMIN_KEYRING} must exist; get it from your existing mon"
        exit 1
    fi
fi

# Create a MGR keyring
rm -rf $MGR_KEYRING
if [ ! -e "$MGR_KEYRING" ]; then
    # Create ceph-mgr key
    timeout 10 ceph --cluster "${CLUSTER}" auth get-or-create mgr."${MGR_NAME}" mon 'allow profile mgr' osd 'allow *' mds 'allow *' -o "$MGR_KEYRING"
    chown --verbose ceph. "$MGR_KEYRING"
    chmod 600 "$MGR_KEYRING"
fi

# start ceph-mgr
exec /usr/bin/ceph-mgr \
  --cluster "${CLUSTER}" \
  --setuser "ceph" \
  --setgroup "ceph" \
  -d \
  -i "${MGR_NAME}"
