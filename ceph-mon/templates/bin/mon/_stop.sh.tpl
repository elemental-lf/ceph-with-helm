#!/bin/bash

set -ex

NUMBER_OF_MONS=$(ceph mon stat | awk '$3 == "mons" {print $2}')
if [ "${NUMBER_OF_MONS}" -gt "1" ]; then
  ceph mon remove "${NODE_NAME}"
else
  echo "we are the last mon, not removing"
fi
