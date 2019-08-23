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

echo "SUCCESS"

ceph --cluster "${CLUSTER}" -v

# Env. variables matching the pattern "<module>_" will be
# found and parsed for config-key settings by
#  ceph config set mgr mgr/<module>/<key> <value>
MODULES_TO_DISABLE=`ceph mgr dump | python -c "import json, sys; print ' '.join(json.load(sys.stdin)['modules'])"`

for module in ${ENABLED_MODULES}; do
    # This module may have been enabled in the past
    # remove it from the disable list if present
    MODULES_TO_DISABLE=${MODULES_TO_DISABLE/$module/}

    options=`env | grep ^${module}_ || true`
    for option in ${options}; do
        #strip module name
        option=${option/${module}_/}
        key=`echo $option | cut -d= -f1`
        value=`echo $option | cut -d= -f2`
        ceph --cluster "${CLUSTER}" config set mgr mgr/$module/$key $value
    done
    ceph --cluster "${CLUSTER}" mgr module enable ${module} --force
done

for module in $MODULES_TO_DISABLE; do
  ceph --cluster "${CLUSTER}" mgr module disable ${module}
done

echo "SUCCESS"
# start ceph-mgr
exec /usr/bin/ceph-mgr \
  --cluster "${CLUSTER}" \
  --setuser "ceph" \
  --setgroup "ceph" \
  -d \
  -i "${MGR_NAME}"
