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

: "${OSD_PATH_BASE:=/var/lib/ceph/osd/${CLUSTER}}"

OSD_PID="$(cat /run/ceph-osd.pid)"

while pkill -0 -P ${OSD_PID} >/dev/null 2>&1; do
  # ceph-osd is wrapped in /usr/bin/flock.  pkill -P kills the child
  # (ceph-osd) and flock follows suit.
  pkill -SIGTERM -P ${OSD_PID}
  sleep 1
done
# We used to umount here, but the mount is cleanup up when the container
# exits anyway.
