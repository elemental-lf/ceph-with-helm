FROM quay.io/ceph/ceph:v18.2.0

LABEL version="18.2.0-k8s-1.26.7-rev-1"
LABEL maintainer="lf@elemental.net"

ARG KUBECTL_VERSION=v1.26.7

RUN set -ex && \
    curl -sSL -o /usr/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl && \
    chmod +x /usr/bin/kubectl && \
    dnf clean all
