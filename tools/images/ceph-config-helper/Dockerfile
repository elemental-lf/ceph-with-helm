FROM docker.io/ceph/daemon-base:v5.0.11-stable-5.0-octopus-centos-8-x86_64

LABEL version="5.0.11-octopus-k8s-1.19.11-rev-1"
LABEL maintainer="lf@elemental.net"

ARG KUBECTL_VERSION=v1.19.11

RUN set -ex && \
    yum install -y epel-release && \
    yum install -y jq python3-pip && \
    pip3 --no-cache-dir install --upgrade \
      crush \
      rgwadmin && \
    curl -sSL -o /usr/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl && \
    chmod +x /usr/bin/kubectl && \
    yum clean all
