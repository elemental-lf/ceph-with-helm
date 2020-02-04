#!/usr/bin/python2
import re
import os
import subprocess
import json

# Old style output
MON_REGEX_1 = r"^\d: ([0-9\.]*):\d+/\d* mon.([^ ]*)$"
# Newer Ceph versions which support messenger V2 protocol
MON_REGEX_2 = r"^\d: \[v\d+:([\d+.]+):\d+/\d+,.*? mon.(\S+)$"

kubectl_command = 'kubectl get pods --namespace=${NAMESPACE} ' \
    '-l component=mon,application=ceph ' \
    '-o template ' \
    '--template="{ {{"{{"}}range  \$i, \$v  := .items{{"}}"}} {{"{{"}} if \$i{{"}}"}} , {{"{{"}} end {{"}}"}} \\"{{"{{"}}\$v.spec.nodeName{{"}}"}}\\": \\"{{"{{"}}\$v.status.podIP{{"}}"}}\\" {{"{{"}}end{{"}}"}} }"'


monmap_command = 'ceph --cluster=${CLUSTER} mon getmap > /tmp/monmap && '\
    'monmaptool -f /tmp/monmap --print'


def extract_mons_from_monmap():
    monmap = subprocess.check_output(monmap_command, shell=True)
    mons = {}
    for line in monmap.split("\n"):
        m = re.match(MON_REGEX_1, line)
        if m is not None:
            mons[m.group(2)] = m.group(1)
            continue
        m = re.match(MON_REGEX_2, line)
        if m is not None:
            mons[m.group(2)] = m.group(1)
    return mons


def extract_mons_from_kubeapi():
    kubemap = subprocess.check_output(kubectl_command, shell=True)
    return json.loads(kubemap)

current_mons = extract_mons_from_monmap()
expected_mons = extract_mons_from_kubeapi()

print('current mons:{}'.format(current_mons))
print('expected mons:{}'.format(expected_mons))

for mon in current_mons:
    if mon not in expected_mons:
        print("Removing zombie mon {}".format(mon))
        subprocess.call(["ceph", "--cluster", os.environ["CLUSTER"], "mon", "remove", mon])
    # Check if for some reason the IP of the mon changed
    elif current_mons[mon] != expected_mons[mon]:
        print("IP change dedected for pod {}".format(mon))
        subprocess.call(["kubectl", "--namespace", os.environ["NAMESPACE"], "delete", "pod", mon])
        print("Deleted mon {} via the Kubernetes API".format(mon))
