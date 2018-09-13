## Helm Charts for Ceph

This is a fork of https://github.com/openstack/openstack-helm containing
only the Ceph related charts.  (These charts have now been moved to
https://github.com/openstack/openstack-helm-infra by Openstack-Helm people). 
I use these charts for one of my projects at work.  Notable differences at
the time of writing (09/13/2018):

 - Update Ceph from Luminous to Mimic
 - Use of Ceph's new centralized configuration management
 - Update of cephfs and rbd provisioners
 - Removal of local registry/repository sync and Keystone support
 - Unified values.yaml
