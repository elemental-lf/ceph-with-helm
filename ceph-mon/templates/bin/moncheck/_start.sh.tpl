#!/bin/bash
set -e
export LC_ALL=C

function watch_mon_health {
  while true; do
    echo "Checking for zombie mons"
    /tmp/moncheck-reap-zombies.py || true
    echo "Sleep 30 sec"
    sleep 30
  done
}

watch_mon_health
