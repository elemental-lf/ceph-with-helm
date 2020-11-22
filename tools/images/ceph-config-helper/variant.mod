provisioners:
  files:
    Dockerfile:
      source: Dockerfile.tpl
      arguments:
        ceph_daemon_base_image_tag: "v{{ .ceph_daemon_base.version }}-stable-4.0-nautilus-centos-7-x86_64"
        ceph_container_version: "{{ .ceph_daemon_base.version }}"
        ceph_container_release_name: "nautilus"
        kubectl_version: "{{ .kubectl.version }}"
        revision: "1"

dependencies:
  ceph_daemon_base:
    releasesFrom:
      githubReleases:
        source: ceph/ceph-container
    version: "~> 4.0.0"
  kubectl:
    releasesFrom:
      githubReleases:
        source: kubernetes/kubernetes
    version: "~> 1.18.0"
