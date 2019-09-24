## Helm Charts for Ceph

This originally was a fork of https://github.com/openstack/openstack-helm containing only the Ceph related charts.  
(These charts have now been moved to https://github.com/openstack/openstack-helm-infra by the Openstack-Helm
people.) Since then some things have diverged considerably. Notable differences at the time of writing (11/09/2019):

 - Based on Ceph Nautilus 
 - Uses a Kubernetes operator for the OSDs
 - Uses ceph-volume and only supports BlueStore
 - Uses CentOS 7 based images from the `ceph-container` project
 - `ceph-config-helper` image is based on `ceph/daemon-base`
 - Use of Ceph's new centralized configuration management
 - Update of CephFS and RBD provisioners (RBD provisioner supports additional RBD image features)
 - Removal of local registry/repository sync and Keystone support
 - Unified values.yaml

### Links

* [Ceph OSD Operator](https://github.com/elemental-lf/ceph-osd-operator/)
* [Fork of cephfs and RBD provisioner](https://github.com/elemental-lf/external-storage)

### Releases

* `milestone-1`: This version was running in production for several month and includes Ceph Mimic (13.2.6) in
  its last incarnation.

* `milestone-2`: This is major update of the Helm charts and it contains some not backwards compatible changes in
  `values.yaml`. Notable changes are:
    * Adds security contexts to most pods and tries to minimize the needed privileges by mounting container images
    read-only, running as nobody among other things. (Adapted in large parts from `openstack-helm-infra`.)
    * DaemonSet's and Deployment's update strategy can now be configure via `values.yaml`. (Adapted in large parts
    from `openstack-helm-infra`.)
    * Ceph configuration changes  (`conf.ceph` in `values.yaml`) are now not only applied when creating the Ceph
      cluster but also to the running cluster. Only additions and changes are supported. Deletions still have to be done
      by hand.
    * It is now possible to configure additional storage classes and to configure a storage class as the default. But
      there currently is the limitation that the client key installation is only done for the standard RBD storage
      class `rbd`.
    * Fixed balancer default configuration to use mode `crush-compat` instead of the newer `upmap`. KRBD clients are
      still at Jewel feature level in Linux Kernel 4.19 and so the balancer never did anything. For existing clusters
      this will start shuffling some data around. If this is not desired I suggest to set
      `ceph_mgr_modules_config.balancer.active` to `0`. This disables automatic balancing.
    * Changing S3 admin key and secret via `values.yaml` is now supported. (Also ported from `openstack-helm-infra`.)

* `milestone-3`: This is a major update and brings Ceph to version 14.2.2.
    * Updates `ceph-container` to 4.0.3 which includes Ceph 14.2.2.
    * Health check scripts are rewritten (includes an important bug fix to the mon check script)
    * Fixed probably endless loop in wait_for_inactive_pgs due to changed `ceph pg ls` output.
    * Enabled messenger v2 protocol for all components
    * Updated locking logic for OSD block devices, Nautilus does the locking internally now
    * Updated `ceph-config-helper` image: Ceph to 14.2.2 and `kubectl` to 1.15.3
    
  **Remember to execute `osd require-osd-release nautilus` after the upgrade is complete and you're confident that you
    don't want to go back.**

* `milestone-4`: This updates the Ceph OSD operator.
    * Update to Operator SDK 0.10.0

    The Ceph OSD operator update changes the name of the custom resource definition as it was using the singular form
    by mistake. So before upgrading the chart two additional steps are needed:
    
    ```shell
    # Delete the old CRD
    kubectl delete crd cephosd.ceph.elemental.net
    # Install the new CRD
    kubectl create -f ceph-with-helm/ceph-osd/templates/ceph_v1alpha1_cephosd_crd.yaml
    ```
    **This will temporarily delete any existing CephOSD custom resources and so all OSD pods. OSD data is not affected
    and safe.** The custom resources will need to be reinstalled either by upgrading the `ceph-osd` chart or by other 
    means if they reside outside of the chart. After the new operator is operational it will recreate all OSD pods. 
    It is advisable  to mark all OSDs as `noout` for the time of the upgrade to prevent any unwanted data shuffling.

Commits between these milestone should be mostly bug fixes and minor other changes.
