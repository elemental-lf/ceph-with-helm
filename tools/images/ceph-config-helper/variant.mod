provisioners:
  files:
    Dockerfile:
      source: Dockerfile.tpl
      arguments:
        ceph_daemon_base_image_tag: "v{{ .ceph_daemon_base.version }}-stable-5.0-octopus-centos-8-x86_64"
        ceph_container_version: "{{ .ceph_daemon_base.version }}"
        ceph_container_release_name: "octopus"
        kubectl_version: "{{ .kubectl.version }}"
        revision: "1"

dependencies:
  ceph_daemon_base:
    releasesFrom:
      githubReleases:
        source: ceph/ceph-container
    version: "~> 5.0.0"
  kubectl:
    releasesFrom:
      githubReleases:
        source: kubernetes/kubernetes
    version: "~> 1.20.0"
