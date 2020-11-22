FROM docker.io/ceph/daemon-base:{{ .ceph_daemon_base_image_tag }}

LABEL version="{{ .ceph_container_version }}-{{ .ceph_container_release_name }}-k8s-{{ .kubectl_version }}-rev-{{ .revision }}"
LABEL maintainer="lf@elemental.net"

ARG KUBECTL_VERSION=v{{ .kubectl_version }}

RUN set -ex && \
    yum install -y epel-release && \
    yum install -y jq python3-pip && \
    pip3 --no-cache-dir install --upgrade \
      crush \
      rgwadmin && \
    curl -sSL -o /usr/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl && \
    chmod +x /usr/bin/kubectl && \
    yum clean all
