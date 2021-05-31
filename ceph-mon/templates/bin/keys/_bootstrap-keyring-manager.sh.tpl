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
else
  CURRENT_CEPH_USER="$(kubectl get --namespace ${DEPLOYMENT_NAMESPACE} secret ${KUBE_SECRET_NAME} -o jsonpath='{.data.user}')"
  CURRENT_CEPH_KEY="$(kubectl get --namespace ${DEPLOYMENT_NAMESPACE} secret ${KUBE_SECRET_NAME} -o jsonpath='{.data.key}')"
  CURRENT_CEPH_KEYRING="$(kubectl get --namespace ${DEPLOYMENT_NAMESPACE} secret ${KUBE_SECRET_NAME} -o jsonpath='{.data.keyring}')"

  if [[ -z $CURRENT_CEPH_USER || -z $CURRENT_CEPH_KEY || -z $CURRENT_CEPH_KEYRING ]]; then
    CURRENT_CEPH_KEYRING="$(kubectl get --namespace ${DEPLOYMENT_NAMESPACE} secret ${KUBE_SECRET_NAME} -o json | jq -r '.data."ceph.keyring" // .data."ceph.client.admin.keyring" // .data."ceph.mon.keyring"' | base64 -d)"
    if [[ -z $CURRENT_CEPH_KEYRING ]]; then
      echo "ERROR- Unable to extract current legacy keyring from secret ${KUBE_SECRET_NAME}"
      echo "ERROR- Not patching secret."
      exit 1
    fi

    CURRENT_CEPH_KEY="$(sed -e '2q;d' <<<"${CURRENT_CEPH_KEYRING}" | sed -e 's/^[     ]\+key[         ]\+=[   ]\+\(.\+\)$/\1/')"

    kubectl patch --namespace ${DEPLOYMENT_NAMESPACE} secret ${KUBE_SECRET_NAME} -p "{
      \"data\": {
        \"user\": \"$(echo -n "$CEPH_USER" | base64 -w0)\",
        \"key\": \"$(echo -n "$CURRENT_CEPH_KEY" | base64 -w0)\",
        \"keyring\": \"$(echo "$CURRENT_CEPH_KEYRING" | base64 -w0)\"
      }
    }"
  fi
fi
