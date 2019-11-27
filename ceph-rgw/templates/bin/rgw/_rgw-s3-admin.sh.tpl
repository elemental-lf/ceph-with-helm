#!/bin/bash

{{/*
Copyright 2018 The Openstack-Helm Authors.

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

function create_admin_user () {
  radosgw-admin user create \
    --uid=${S3_ADMIN_USERNAME} \
    --display-name=${S3_ADMIN_USERNAME} \
    --system

  radosgw-admin caps add \
      --uid=${S3_ADMIN_USERNAME} \
      --caps={{ .Values.conf.rgw_s3.admin_caps | quote }}

  radosgw-admin key create \
    --uid=${S3_ADMIN_USERNAME} \
    --key-type=s3 \
    --access-key ${S3_ADMIN_ACCESS_KEY} \
    --secret-key ${S3_ADMIN_SECRET_KEY}
}

function update_admin_user () {
  # Retrieve old access keys, if they exist
  old_access_keys=$(radosgw-admin user info --uid=${S3_ADMIN_USERNAME} \
    | jq -r '.keys[].access_key' || true)

  access_key_found=0
  if [[ ! -z ${old_access_keys} ]]; then
    for access_key in $old_access_keys; do
      # If current access key is the same as the key supplied, do nothing.
      if [ "$access_key" == "${S3_ADMIN_ACCESS_KEY}" ]; then
        echo "Current key pair exists."
        access_key_found=1
      else
        # If keys differ, remove previous key
        radosgw-admin key rm --uid=${S3_ADMIN_USERNAME} --key-type=s3 --access-key=$access_key
      fi
    done
  fi

  # If the supplied key does not exist, modify the user
  if [[ ${access_key_found} == 0 ]]; then
    # Modify user with new access and secret keys
    echo "Updating key pair."
    radosgw-admin user modify \
      --uid=${S3_ADMIN_USERNAME} \
      --access-key ${S3_ADMIN_ACCESS_KEY} \
      --secret-key ${S3_ADMIN_SECRET_KEY}
  fi
}

user_exists=$(radosgw-admin user info --uid=${S3_ADMIN_USERNAME} || true)
if [[ -z ${user_exists} ]]; then
  create_admin_user
else
  update_admin_user
fi
