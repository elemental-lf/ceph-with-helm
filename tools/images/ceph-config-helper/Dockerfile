FROM docker.io/ceph/daemon-base:v4.0.10-stable-4.0-nautilus-centos-7-x86_64
MAINTAINER lf@elemental.net

ARG KUBECTL_VERSION=v1.17.3

RUN set -ex;\
    yum install -y jq python2-pip; \
    pip --no-cache-dir install --upgrade \
      crush \
      rgwadmin \
      six; \
    curl -sSL -o /usr/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl; \
    chmod +x /usr/bin/kubectl; \
    yum clean all
