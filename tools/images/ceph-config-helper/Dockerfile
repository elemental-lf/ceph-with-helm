FROM docker.io/ceph/daemon-base:v3.2.5-stable-3.2-mimic-centos-7-x86_64
MAINTAINER lf@elemental.net

ARG KUBECTL_VERSION=v1.15.2

RUN set -ex;\
    yum install -y jq python2-pip; \
    pip --no-cache-dir install --upgrade \
      crush \
      rgwadmin \
      six; \
    curl -sSL -o /usr/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl; \
    chmod +x /usr/bin/kubectl; \
    yum clean all
