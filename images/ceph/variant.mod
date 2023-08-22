provisioners:
  files:
    Dockerfile:
      source: Dockerfile.tpl
      arguments:
        ceph_version: "{{ .ceph.version }}"
        kubernetes_version: "{{ .kubernetes.version }}"
        revision: "1"

dependencies:
  ceph:
    releasesFrom:
      githubTags:
        source: ceph/ceph
    version: "18.2.*"
  kubernetes:
    releasesFrom:
      githubReleases:
        source: kubernetes/kubernetes
    version: "~ 1.26.0"
