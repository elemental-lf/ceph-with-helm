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

# Read user name from secret and remove client. prefix
CEPH_USER=$(kubectl get secret ${CEPH_CLIENT_ADMIN_SECRET_NAME} --namespace=${DEPLOYMENT_NAMESPACE} \
    -o json | jq -r '.data.user' | base64 -d | sed -e 's/^client\.//' | base64 -w0)
CEPH_KEY=$(kubectl get secret ${CEPH_CLIENT_ADMIN_SECRET_NAME} --namespace=${DEPLOYMENT_NAMESPACE} \
    -o json | jq -r '.data.key')

# TODO: Remove this and the resulting key when CSI migration is done.
if ! kubectl get --namespace ${DEPLOYMENT_NAMESPACE} secrets ${CEPH_STORAGECLASS_ADMIN_SECRET_NAME}; then
  kubectl create --namespace ${DEPLOYMENT_NAMESPACE} -f - <<EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: ${CEPH_STORAGECLASS_ADMIN_SECRET_NAME}
type: kubernetes.io/rbd
data:
  key: ${CEPH_KEY}
EOF
fi
# END TODO

if ! kubectl get --namespace ${DEPLOYMENT_NAMESPACE} secrets ${CEPH_CSI_RBD_SECRET_NAME}; then
  kubectl create --namespace ${DEPLOYMENT_NAMESPACE} -f - <<EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: ${CEPH_CSI_RBD_SECRET_NAME}
data:
  userID: ${CEPH_USER}
  userKey: ${CEPH_KEY}
EOF
fi

if ! kubectl get --namespace ${DEPLOYMENT_NAMESPACE} secrets ${CEPH_CSI_CEPHFS_SECRET_NAME}; then
  kubectl create --namespace ${DEPLOYMENT_NAMESPACE} -f - <<EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: ${CEPH_CSI_CEPHFS_SECRET_NAME}
data:
  # Required for statically provisioned volumes
  userID: ${CEPH_USER}
  userKey: ${CEPH_KEY}
  # Required for dynamically provisioned volumes
  adminID: ${CEPH_USER}
  adminKey: ${CEPH_KEY}
EOF
fi
