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

function osd_disk_prepare {
  if [[ -z "${OSD_DEVICE}" ]];then
    log "ERROR- You must provide a device to build your OSD ie: /dev/sdb"
    exit 1
  fi

  OSD_DEVICE=$(hardware_to_block ${OSD_DEVICE})
  OSD_DEVICE=`readlink -f ${OSD_DEVICE}`

  if [[ ! -b "${OSD_DEVICE}" ]]; then
    log "ERROR- The device pointed by OSD_DEVICE ($OSD_DEVICE) doesn't exist !"
    exit 1
  fi

  if [ ! -e $OSD_BOOTSTRAP_KEYRING ]; then
    log "ERROR- $OSD_BOOTSTRAP_KEYRING must exist. You can extract it from your current monitor by running 'ceph auth get client.bootstrap-osd -o $OSD_BOOTSTRAP_KEYRING'"
    exit 1
  fi
  timeout 10 ceph ${CLI_OPTS} --name client.bootstrap-osd --keyring $OSD_BOOTSTRAP_KEYRING health || exit 1

  # check device status first
  if ! parted --script ${OSD_DEVICE} print > /dev/null 2>&1; then
    if [[ ${OSD_FORCE_ZAP} -eq 1 ]]; then
      log "It looks like ${OSD_DEVICE} isn't consistent, however OSD_FORCE_ZAP is enabled so we are zapping the device anyway"
      ceph-disk -v zap ${OSD_DEVICE}
    else
      log "Regarding parted, device ${OSD_DEVICE} is inconsistent/broken/weird."
      log "It would be too dangerous to destroy it without any notification."
      log "Please set OSD_FORCE_ZAP to '1' if you really want to zap this disk."
      exit 1
    fi
  fi

  # then search for some ceph metadata on the disk
  if [[ "$(parted --script ${OSD_DEVICE} print | egrep '^ 1.*ceph data')" ]]; then
    if [[ ${OSD_FORCE_ZAP} -eq 1 ]]; then
      if [ -b "${OSD_DEVICE}1" ]; then
        local fs=`lsblk -fn ${OSD_DEVICE}1`
        if [ ! -z "${fs}" ]; then
          local cephFSID=`ceph-conf --lookup fsid`
          if [ ! -z "${cephFSID}" ]; then
            local tmpmnt=`mktemp -d`
            mount ${OSD_DEVICE}1 ${tmpmnt}
            if [ -f "${tmpmnt}/ceph_fsid" ]; then
              osdFSID=`cat "${tmpmnt}/ceph_fsid"`
              umount ${tmpmnt}
              if [ ${osdFSID} != ${cephFSID} ]; then
                log "It looks like ${OSD_DEVICE} is an OSD belonging to a different (or old) ceph cluster."
                log "The OSD FSID is ${osdFSID} while this cluster is ${cephFSID}"
                log "Because OSD_FORCE_ZAP was set, we will zap this device."
                ceph-disk -v zap ${OSD_DEVICE}
              else
                log "It looks like ${OSD_DEVICE} is an OSD belonging to a this ceph cluster."
                log "OSD_FORCE_ZAP is set, but will be ignored and the device will not be zapped."
                log "Moving on, trying to activate the OSD now."
                return
              fi
            else
              umount ${tmpmnt}
              log "It looks like ${OSD_DEVICE} has a ceph data partition but no FSID."
              log "Because OSD_FORCE_ZAP was set, we will zap this device."
              ceph-disk -v zap ${OSD_DEVICE}
            fi
          else
            log "Unable to determine the FSID of the current cluster."
            log "OSD_FORCE_ZAP is set, but this OSD will not be zapped."
            log "Moving on, trying to activate the OSD now."
            return
          fi
        else
          log "It looks like ${OSD_DEVICE} has a ceph data partition but no filesystem."
          log "Because OSD_FORCE_ZAP was set, we will zap this device."
          ceph-disk -v zap ${OSD_DEVICE}
        fi
      else
        log "parted says ${OSD_DEVICE}1 should exist, but we do not see it."
        log "We will ignore OSD_FORCE_ZAP and try to use the device as-is"
        log "Moving on, trying to activate the OSD now."
        return
      fi
    else
      log "INFO- It looks like ${OSD_DEVICE} is an OSD, set OSD_FORCE_ZAP=1 to use this device anyway and zap its content"
      log "You can also use the zap_device scenario on the appropriate device to zap it"
      log "Moving on, trying to activate the OSD now."
      return
    fi
  fi

  if [ "${OSD_BLUESTORE:-0}" -ne 1 ]; then
    # we only care about journals for filestore.
    if [ -n "${OSD_JOURNAL}" ]; then
      OSD_JOURNAL=$(hardware_to_block ${OSD_JOURNAL})
      if [ -b $OSD_JOURNAL ]; then
        OSD_JOURNAL=`readlink -f ${OSD_JOURNAL}`
        OSD_JOURNAL_PARTITION=`echo $OSD_JOURNAL_PARTITION | sed 's/[^0-9]//g'`
        if [ -z "${OSD_JOURNAL_PARTITION}" ]; then
          # maybe they specified the journal as a /dev path like '/dev/sdc12':
          local JDEV=`echo ${OSD_JOURNAL} | sed 's/\(.*[^0-9]\)[0-9]*$/\1/'`
          if [ -d /sys/block/`basename $JDEV`/`basename $OSD_JOURNAL` ]; then
            OSD_JOURNAL=$(dev_part ${JDEV} `echo ${OSD_JOURNAL} |\
              sed 's/.*[^0-9]\([0-9]*\)$/\1/'`)
            OSD_JOURNAL_PARTITION=${JDEV}
          fi
        else
          OSD_JOURNAL=$(dev_part ${OSD_JOURNAL} ${OSD_JOURNAL_PARTITION})
        fi
      fi
      chown ceph. ${OSD_JOURNAL}
    else
      OSD_JOURNAL=$(dev_part ${OSD_DEVICE} 2)
      OSD_JOURNAL_PARTITION=2
    fi
    CLI_OPTS="${CLI_OPTS} --filestore"
  else
    OSD_JOURNAL=''
    CLI_OPTS="${CLI_OPTS} --bluestore"
  fi

  if [ -b "${OSD_JOURNAL}" -a "${OSD_FORCE_ZAP:-0}" -eq 1 ]; then
    # if we got here and zap is set, it's ok to wipe the journal.
    log "OSD_FORCE_ZAP is set, so we will erase the journal device ${OSD_JOURNAL}"
    if [ -z "${OSD_JOURNAL_PARTITION}" ]; then
      # it's a raw block device.  nuke any existing partition table.
      parted -s ${OSD_JOURNAL} mklabel msdos
    else
      # we are likely working on a partition. Just make a filesystem on
      # the device, as other partitions may be in use so nuking the whole
      # disk isn't safe.
      mkfs -t xfs -f ${OSD_JOURNAL}
    fi
  fi

  if [[ ${OSD_DMCRYPT} -eq 1 ]]; then
    # the admin key must be present on the node
    if [[ ! -e $ADMIN_KEYRING ]]; then
      log "ERROR- $ADMIN_KEYRING must exist; get it from your existing mon"
      exit 1
    fi
    # in order to store the encrypted key in the monitor's k/v store
    ceph-disk -v prepare ${CLI_OPTS} --journal-uuid ${OSD_JOURNAL_UUID} --lockbox-uuid ${OSD_LOCKBOX_UUID} --dmcrypt ${OSD_DEVICE} ${OSD_JOURNAL}
    echo "Unmounting LOCKBOX directory"
    # NOTE(leseb): adding || true so when this bug will be fixed the entrypoint will not fail
    # Ceph bug tracker: http://tracker.ceph.com/issues/18944
    DATA_UUID=$(blkid -o value -s PARTUUID ${OSD_DEVICE}1)
    umount /var/lib/ceph/osd-lockbox/${DATA_UUID} || true
  else
    ceph-disk -v prepare ${CLI_OPTS} --journal-uuid ${OSD_JOURNAL_UUID} ${OSD_DEVICE} ${OSD_JOURNAL}
  fi

  # watch the udev event queue, and exit if all current events are handled
  udevadm settle --timeout=600
}
