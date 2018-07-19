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

if [ -n "$(cat /proc/*/comm 2>/dev/null | grep libvirtd)" ]; then
    echo "ERROR: libvirtd daemon already running on host" 1>&2
    exit 1
fi

rm -f /var/run/libvirtd.pid

if [[ -c /dev/kvm ]]; then
    chmod 660 /dev/kvm
    chown root:kvm /dev/kvm
fi

# We assume that if hugepage count > 0, then hugepages should be exposed to libvirt/qemu
hp_count="$(cat /proc/meminfo | grep HugePages_Total | tr -cd '[:digit:]')"
if [ 0"$hp_count" -gt 0 ]; then

  echo "INFO: Detected hugepage count of '$hp_count'. Enabling hugepage settings for libvirt/qemu."

  # Enable KVM hugepages for QEMU
  if [ -n "$(grep KVM_HUGEPAGES=0 /etc/default/qemu-kvm)" ]; then
    sed -i 's/.*KVM_HUGEPAGES=0.*/KVM_HUGEPAGES=1/g' /etc/default/qemu-kvm
  else
    echo KVM_HUGEPAGES=1 >> /etc/default/qemu-kvm
  fi

  # Ensure that the hugepage mount location is available/mapped inside the
  # container. This assumes use of the default ubuntu dev-hugepages.mount
  # systemd unit which mounts hugepages at this location.
  if [ ! -d /dev/hugepages ]; then
    echo "ERROR: Hugepages configured in kernel, but libvirtd container cannot access /dev/hugepages"
    exit 1
  fi

  # Kubernetes 1.10.x introduced cgroup changes that caused the container's
  # hugepage byte limit quota to zero out. This workaround sets that pod limit
  # back to the total number of hugepage bytes available to the baremetal host.

  for limit in $(ls /sys/fs/cgroup/hugetlb/kubepods/hugetlb.*.limit_in_bytes); do
    target="/sys/fs/cgroup/hugetlb/$(dirname $(awk -F: '($2~/hugetlb/){print $3}' /proc/self/cgroup))/$(basename $limit)"
    # Ensure the write target for the hugepage limit for the pod exists
    if [ ! -f "$target" ]; then
      echo "ERROR: Could not find write target for hugepage limit: $target"
    fi

    # Write hugetable limit for pod
    echo "$(cat $limit)" > "$target"
  done

  # Determine OS default hugepage size to use for the hugepage write test
  default_hp_kb="$(cat /proc/meminfo | grep Hugepagesize | tr -cd '[:digit:]')"

  # Attempt to write to the hugepage mount to ensure it is operational, but only
  # if we have at least 1 free page.
  num_free_pages="$(cat /sys/kernel/mm/hugepages/hugepages-${default_hp_kb}kB | tr -cd '[:digit:]')"
  echo "INFO: '$num_free_pages' free hugepages of size ${default_hp_kb}kB"
  if [ 0"$num_free_pages" - gt 0 ]; then
    (fallocate -o0 -l "$default_hp_kb" /dev/hugepages/foo && rm /dev/hugepages/foo) || \
      (echo "ERROR: fallocate failed test at /dev/hugepages with size ${default_hp_kb}kB"
       rm /dev/hugepages/foo
       exit 1)
  fi
fi

if [ -n "${LIBVIRT_CEPH_CINDER_SECRET_UUID}" ] ; then
  libvirtd --listen &

  tmpsecret=$(mktemp --suffix .xml)
  function cleanup {
      rm -f "${tmpsecret}"
  }
  trap cleanup EXIT

  # Wait for the libvirtd is up
  TIMEOUT=60
  while [[ ! -f /var/run/libvirtd.pid ]]; do
    if [[ ${TIMEOUT} -gt 0 ]]; then
      let TIMEOUT-=1
      sleep 1
    else
      echo "ERROR: libvirt did not start in time (pid file missing)"
      exit 1
    fi
  done

  # Even though we see the pid file the socket immediately (this is
  # needed for virsh)
  TIMEOUT=10
  while [[ ! -e /var/run/libvirt/libvirt-sock ]]; do
    if [[ ${TIMEOUT} -gt 0 ]]; then
      let TIMEOUT-=1
      sleep 1
    else
      echo "ERROR: libvirt did not start in time (socket missing)"
      exit 1
    fi
  done

  if [ -z "${CEPH_CINDER_KEYRING}" ] ; then
    CEPH_CINDER_KEYRING=$(sed -n 's/^[[:space:]]*key[[:blank:]]\+=[[:space:]]\(.*\)/\1/p' /etc/ceph/ceph.client.${CEPH_CINDER_USER}.keyring)
  fi

  cat > ${tmpsecret} <<EOF
<secret ephemeral='no' private='no'>
  <uuid>${LIBVIRT_CEPH_CINDER_SECRET_UUID}</uuid>
  <usage type='ceph'>
    <name>client.${CEPH_CINDER_USER}. secret</name>
  </usage>
</secret>
EOF

  virsh secret-define --file ${tmpsecret}
  virsh secret-set-value --secret "${LIBVIRT_CEPH_CINDER_SECRET_UUID}" --base64 "${CEPH_CINDER_KEYRING}"

  # rejoin libvirtd
  wait
else
  exec libvirtd --listen
fi
