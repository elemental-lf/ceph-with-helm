## Helm Charts for Ceph

This is a fork of https://github.com/openstack/openstack-helm containing
only the Ceph related charts.  (These charts have now been moved to
https://github.com/openstack/openstack-helm-infra by the Openstack-Helm people). 
I use these charts for one of my projects at work.  Notable differences at
the time of writing (09/13/2018):

 - Move Ceph from Ubuntu to CentOS 7 based images as Ubuntu is no longer supported in Mimic
 - Update Ceph from Luminous to Mimic
 - ceph-config-helper image is based on ceph/daemon-base
 - Use of Ceph's new centralized configuration management
 - Update of cephfs and rbd provisioners
 - Removal of local registry/repository sync and Keystone support
 - Unified values.yaml
