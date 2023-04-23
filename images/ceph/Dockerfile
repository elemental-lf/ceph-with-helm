FROM quay.io/ceph/ceph:v17.2.6

LABEL version="17.2.6-k8s-1.25.9-rev-1"
LABEL maintainer="lf@elemental.net"

ARG KUBECTL_VERSION=v1.25.9

RUN set -ex && \
    curl -sSL -o /usr/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl && \
    chmod +x /usr/bin/kubectl && \
    dnf clean all
