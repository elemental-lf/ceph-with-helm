FROM quay.io/ceph/ceph:v{{ .ceph_version }}

LABEL version="{{ .ceph_version }}-k8s-{{ .kubernetes_version }}-rev-{{ .revision }}"
LABEL maintainer="lf@elemental.net"

ARG KUBECTL_VERSION=v{{ .kubernetes_version }}

RUN set -ex && \
    curl -sSL -o /usr/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl && \
    chmod +x /usr/bin/kubectl && \
    dnf clean all
