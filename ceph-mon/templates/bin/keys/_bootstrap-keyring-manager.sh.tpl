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

function ceph_gen_key () {
  ${CEPH_GEN_DIR}/keys-bootstrap-keyring-generator.py
}

function kube_ceph_keyring_gen () {
  CEPH_KEY=$1
  CEPH_KEYRING_TEMPLATE=$2
  echo -n "${CEPH_KEYRING_TEMPLATE}" | sed "s|{{"{{"}} key {{"}}"}}|${CEPH_KEY}|" | base64 -w0
}

if ! kubectl get --namespace ${DEPLOYMENT_NAMESPACE} secrets ${KUBE_SECRET_NAME}; then
  CEPH_KEY="$(ceph_gen_key)"

  kubectl create --namespace ${DEPLOYMENT_NAMESPACE} -f - <<EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: ${KUBE_SECRET_NAME}
type: Opaque
data:
  user: $(echo -n "$CEPH_USER" | base64 -w0)
  key: $(echo -n "$CEPH_KEY" | base64 -w0)
  keyring: $(kube_ceph_keyring_gen "${CEPH_KEY}" "${CEPH_KEYRING_TEMPLATE}")
EOF
fi

