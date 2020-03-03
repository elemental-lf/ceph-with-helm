#!/bin/bash
set -ex
export LC_ALL=C
: "${MON_KEYRING:=/etc/ceph/${CLUSTER}.mon.keyring}"
: "${ADMIN_KEYRING:=/etc/ceph/${CLUSTER}.client.admin.keyring}"
: "${MDS_BOOTSTRAP_KEYRING:=/var/lib/ceph/bootstrap-mds/${CLUSTER}.keyring}"
: "${OSD_BOOTSTRAP_KEYRING:=/var/lib/ceph/bootstrap-osd/${CLUSTER}.keyring}"
: "${RGW_BOOTSTRAP_KEYRING:=/var/lib/ceph/bootstrap-rgw/${CLUSTER}.keyring}"
: "${RBD_MIRROR_BOOTSTRAP_KEYRING:=/var/lib/ceph/bootstrap-rbd/${CLUSTER}.keyring}"

if [[ -z "$CEPH_PUBLIC_NETWORK" ]]; then
  echo "ERROR- CEPH_PUBLIC_NETWORK must be defined as the name of the network for the OSDs"
  exit 1
fi

if [[ -z "$MON_IP" ]]; then
  echo "ERROR- MON_IP must be defined as the IP address of the monitor"
  exit 1
fi

MON_NAME=${NODE_NAME}
MON_DATA_DIR="/var/lib/ceph/mon/${CLUSTER}-${MON_NAME}"
MONMAP="/etc/ceph/monmap-${CLUSTER}"
TIMEOUT=10
# Set to 0 when any of the monitors are still Mimic or Luminous
ALL_SUPPORT_V2=1

# Make the monitor directory
su -s /bin/sh -c "mkdir -p \"${MON_DATA_DIR}\"" ceph

function get_mon_config {
  # Get fsid from ceph.conf
  local -r fsid="$(ceph-conf --lookup fsid -c /etc/ceph/${CLUSTER}.conf)"

  local remaining=$TIMEOUT
  while [[ ${remaining} > 0 ]]; do
    # Get the ceph mon pods (name, IP and image) from the Kubernetes API. Formatted as a set of monmap params
    local monmap_add_v1=''
    local monmap_add_v1_v2=''
    while read -r line; do
      local node_name="$(cut -f1 <<<"$line")"
      local pod_ip="$(cut -f2 <<<"$line")"
      local image="$(cut -f3 <<<"$line")"

      monmap_add_v1="$monmap_add_v1 --addv $node_name [v1:$pod_ip:6789]"
      monmap_add_v1_v2="$monmap_add_v1_v2 --addv $node_name [v2:$pod_ip:3300,v1:$pod_ip:6789]"
      [[ $image =~ mimic|luminous ]] && ALL_SUPPORT_V2=0
    done < <(kubectl get pods --namespace=${NAMESPACE} ${KUBECTL_PARAM} -o jsonpath='{range .items[?(@.status.podIP)]}{.spec.nodeName}{"\t"}{.status.podIP}{"\t"}{.spec.containers[0].image}{"\n"}{end}')

    [[ -n $monmap_add_v1 ]] && break
    (( remaining-- ))
    sleep 1
  done

  if [[ -z ${monmap_add_v1} ]]; then
      echo "ERROR- No ceph-mon pods found after ${TIMEOUT} seconds, exiting (namespace ${NAMESPACE}, KUBECTL_PARAM: ${KUBECTL_PARAM})."
      exit 1
  fi

  # Create a monmap with the Pod Names and IP
  if [[ $ALL_SUPPORT_V2 == 1 ]]; then
    monmaptool --create ${monmap_add_v1_v2} --fsid ${fsid} "${MONMAP}" --clobber
  else
    monmaptool --create ${monmap_add_v1} --fsid ${fsid} "${MONMAP}" --clobber
  fi
}

# Must be called for ALL_SUPPORT_V2 to be set correctly
get_mon_config

if [ ! -e ${MON_KEYRING}.seed ]; then
  echo "ERROR- ${MON_KEYRING}.seed must exist. You can extract it from your current monitor by running 'ceph auth get mon. -o ${MON_KEYRING}' or use a KV Store"
  exit 1
else
  cp -vf ${MON_KEYRING}.seed ${MON_KEYRING}
fi

# Import all other keys into the keyring
for KEYRING in ${OSD_BOOTSTRAP_KEYRING} ${MDS_BOOTSTRAP_KEYRING} ${RGW_BOOTSTRAP_KEYRING} ${RBD_MIRROR_BOOTSTRAP_KEYRING} ${ADMIN_KEYRING}; do
  ceph-authtool ${MON_KEYRING} --import-keyring ${KEYRING}
done

# If we don't have a monitor keyring, this is a new monitor
if [ ! -e "${MON_DATA_DIR}/keyring" ]; then
  if [ ! -e ${MONMAP} ]; then
    echo "ERROR- ${MONMAP} must exist. You can extract it from your current monitor by running 'ceph mon getmap -o ${MONMAP}' or use a KV Store"
    exit 1
  fi

  # Prepare the monitor daemon's directory with the map and keyring
  ceph-mon --setuser ceph --setgroup ceph --cluster "${CLUSTER}" --mkfs -i ${MON_NAME} --inject-monmap ${MONMAP} --keyring ${MON_KEYRING} --mon-data "${MON_DATA_DIR}"
else
  ceph-mon --setuser ceph --setgroup ceph --cluster "${CLUSTER}" -i ${MON_NAME} --inject-monmap ${MONMAP} --keyring ${MON_KEYRING} --mon-data "${MON_DATA_DIR}"
  if [[ $ALL_SUPPORT_V2 == 1 ]]; then
    timeout $[$TIMEOUT * 2] ceph --cluster "${CLUSTER}" mon enable-msgr2 || true
    timeout $[$TIMEOUT * 2] ceph --cluster "${CLUSTER}" mon add "${MON_NAME}" "${MON_IP}" || true
  else
    timeout $[$TIMEOUT * 2] ceph --cluster "${CLUSTER}" mon add "${MON_NAME}" "${MON_IP}:6789" || true
  fi
fi

# start MON
exec /usr/bin/ceph-mon \
  --cluster "${CLUSTER}" \
  --setuser "ceph" \
  --setgroup "ceph" \
  -d \
  -i ${MON_NAME} \
  --mon-data "${MON_DATA_DIR}" \
  --public-addr "${MON_IP}"
