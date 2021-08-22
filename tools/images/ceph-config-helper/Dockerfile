FROM docker.io/ceph/daemon-base:v6.0.4-stable-6.0-pacific-centos-8-x86_64

LABEL version="6.0.4-pacific-k8s-1.21.4-rev-1"
LABEL maintainer="lf@elemental.net"

ARG KUBECTL_VERSION=v1.21.4

RUN set -ex && \
    yum install -y epel-release && \
    yum install -y jq python3-pip && \
    pip3 --no-cache-dir install --upgrade \
      crush \
      rgwadmin && \
    curl -sSL -o /usr/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl && \
    chmod +x /usr/bin/kubectl && \
    yum clean all
