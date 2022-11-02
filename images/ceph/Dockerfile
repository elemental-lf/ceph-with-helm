FROM quay.io/ceph/ceph:v17.2.5

LABEL version="17.2.5-k8s-1.25.3-rev-1"
LABEL maintainer="lf@elemental.net"

ARG KUBECTL_VERSION=v1.25.3

RUN set -ex && \
    curl -sSL -o /usr/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl && \
    chmod +x /usr/bin/kubectl && \
    dnf clean all
