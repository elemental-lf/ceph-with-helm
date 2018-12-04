## Helm Charts for Ceph

This originally was a fork of https://github.com/openstack/openstack-helm
containing only the Ceph related charts.  (These charts have now been moved
to https://github.com/openstack/openstack-helm-infra by the Openstack-Helm
people). Since then some things have diverged considerably. Notable differences 
at the time of writing (12/04/2018):

 - Uses a Kubernetes operator for the OSDs
 - Uses ceph-volume and only supports BlueStore
 - Update Ceph from Luminous to Mimic
 - Move Ceph from Ubuntu to CentOS 7 based images as Ubuntu is no longer supported in Mimic
 - ceph-config-helper image is based on ceph/daemon-base
 - Use of Ceph's new centralized configuration management
 - Update of cephfs and RBD provisioners
 - Removal of local registry/repository sync and Keystone support
 - Unified values.yaml

For more information about the Ceph OSD operator, please see the 
[its README](https://github.com/elemental-lf/ceph-osd-operator/blob/master/README.md).
