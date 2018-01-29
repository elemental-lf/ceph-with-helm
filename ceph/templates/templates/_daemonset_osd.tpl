{{- define "daemonset_osd.tpl" }}
{{ $ctxt := index . 0 }}
{{- $value := index . 1 -}}
{{- $serviceAccountName := index . 2 }}
{{- $dependencies := $ctxt.Values.dependencies.osd }}
---
kind: DaemonSet
apiVersion: apps/v1beta2
metadata:
  {{- if $value }}
  name: ceph-osd-{{ $value.type }}-{{ $value.name }}
  {{ else }}
  name: ceph-osd
  {{- end }}
spec:
  updateStrategy:
    type: OnDelete
  selector:
    matchLabels:
{{ tuple $ctxt "ceph" "osd" | include "helm-toolkit.snippets.kubernetes_metadata_labels" | indent 6 }}
  template:
    metadata:
      labels:
{{ tuple $ctxt "ceph" "osd" | include "helm-toolkit.snippets.kubernetes_metadata_labels" | indent 8 }}
    spec:
      serviceAccountName: {{ $serviceAccountName }}
      nodeSelector:
        {{ $ctxt.Values.labels.osd.node_selector_key }}: {{ $ctxt.Values.labels.osd.node_selector_value }}
        {{- if $value }}
        cephosd-{{ $value.type }}-{{ $value.name }}: enabled
        {{- end }}
    {{- if $ctxt.Values.tolerations.osd }}
      tolerations:
{{ toYaml $ctxt.Values.tolerations.osd | indent 8 }}
    {{- end }}
      hostNetwork: true
      hostPID: true
      dnsPolicy: {{ $ctxt.Values.pod.dns_policy }}
      initContainers:
{{ tuple $ctxt $dependencies list | include "helm-toolkit.snippets.kubernetes_entrypoint_init_container" | indent 8 }}
        - name: ceph-init-dirs
          image: {{ $ctxt.Values.images.tags.ceph_daemon }}
          imagePullPolicy: {{ $ctxt.Values.images.pull_policy }}
          command:
            - /tmp/init_dirs.sh
          volumeMounts:
            - name: ceph-bin
              mountPath: /tmp/init_dirs.sh
              subPath: init_dirs.sh
              readOnly: true
            - name: ceph-bin
              mountPath: /variables_entrypoint.sh
              subPath: variables_entrypoint.sh
              readOnly: true
            - name: pod-var-lib-ceph
              mountPath: /var/lib/ceph
              readOnly: false
            - name: pod-run
              mountPath: /run
              readOnly: false
        {{- if $value }}
        {{- if eq $value.type "device" }}
        - name: osd-prepare-pod
          image: {{ $ctxt.Values.images.tags.ceph_daemon }}
          imagePullPolicy: {{ $ctxt.Values.images.pull_policy }}
          command:
            - /start_osd.sh
          ports:
            - containerPort: 6800
          volumeMounts:
            - name: devices
              mountPath: /dev
              readOnly: false
            - name: pod-var-lib-ceph
              mountPath: /var/lib/ceph
              readOnly: false
            - name: pod-run
              mountPath: /run
              readOnly: false
            - name: ceph-bin
              mountPath: /variables_entrypoint.sh
              subPath: variables_entrypoint.sh
              readOnly: true
            - name: ceph-bin
              mountPath: /start_osd.sh
              subPath: start_osd.sh
              readOnly: true
            - name: ceph-bin
              mountPath: /osd_disks.sh
              subPath: osd_disks.sh
              readOnly: true
            - name: ceph-bin
              mountPath: /osd_activate_journal.sh
              subPath: osd_activate_journal.sh
              readOnly: true
            - name: ceph-bin
              mountPath: /osd_disk_activate.sh
              subPath: osd_disk_activate.sh
              readOnly: true
            - name: ceph-bin
              mountPath: /osd_disk_prepare.sh
              subPath: osd_disk_prepare.sh
              readOnly: true
            - name: ceph-bin
              mountPath: /common_functions.sh
              subPath: common_functions.sh
              readOnly: true
            - name: ceph-etc
              mountPath: /etc/ceph/ceph.conf
              subPath: ceph.conf
              readOnly: true
            - name: ceph-client-admin-keyring
              mountPath: /etc/ceph/ceph.client.admin.keyring
              subPath: ceph.client.admin.keyring
              readOnly: false
            - name: ceph-mon-keyring
              mountPath: /etc/ceph/ceph.mon.keyring
              subPath: ceph.mon.keyring
              readOnly: false
            - name: ceph-bootstrap-osd-keyring
              mountPath: /var/lib/ceph/bootstrap-osd/ceph.keyring
              subPath: ceph.keyring
              readOnly: false
            - name: ceph-bootstrap-mds-keyring
              mountPath: /var/lib/ceph/bootstrap-mds/ceph.keyring
              subPath: ceph.keyring
              readOnly: false
            - name: ceph-bootstrap-rgw-keyring
              mountPath: /var/lib/ceph/bootstrap-rgw/ceph.keyring
              subPath: ceph.keyring
              readOnly: false
          securityContext:
            privileged: true
          env:
            - name: CEPH_DAEMON
              value: osd_ceph_disk_prepare
            - name: KV_TYPE
              value: k8s
            - name: CLUSTER
              value: ceph
            - name: CEPH_GET_ADMIN_KEY
              value: "1"
            - name: OSD_DEVICE
              value: {{ $value.device }}
            {{- if $value.journal }}
            {{- if $value.journal | kindIs "string" }}
            - name: OSD_JOURNAL
              value: {{ $value.journal }}
            {{- else }}
            {{- if $value.journal.device }}
            - name: OSD_JOURNAL
              value: {{ $value.journal.device }}
            {{- end }}
            {{- if $value.journal.partition }}
            - name: OSD_JOURNAL_PARTITION
              value: {{ $value.journal.partition | quote }}
            {{- end }}
            {{- end }}
            {{- end }}
            {{- if $value.bluestore }}
            - name: OSD_BLUESTORE
              value: "1"
            {{- end }}
            {{- if $value.zap }}
            - name: OSD_FORCE_ZAP
              value: {{ $value.zap | quote }}
            {{- end }}
            {{- if $ctxt.Values.debug }}
            - name: DEBUG
              value: {{ $ctxt.Values.debug }}
            {{- end }}
            - name: HOSTNAME
              {{- if $value.hostname }}
              value: {{ $value.hostname }}
              {{- else }}
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
              {{- end }}
        #end of device type check
        {{- end }}
        {{- end }}
      containers:
        - name: osd-activate-pod
          image: {{ $ctxt.Values.images.tags.ceph_daemon }}
          imagePullPolicy: {{ $ctxt.Values.images.pull_policy }}
{{ tuple $ctxt $ctxt.Values.pod.resources.osd | include "helm-toolkit.snippets.kubernetes_resources" | indent 10 }}
          command:
            - /start_osd.sh
          securityContext:
            privileged: true
          {{- if not $value }}
          ports:
            - containerPort: 6800
          {{- end }}
          volumeMounts:
            - name: pod-var-lib-ceph
              mountPath: /var/lib/ceph
              readOnly: false
            - name: pod-run
              mountPath: /run
              readOnly: false
            - name: ceph-bin
              mountPath: /start_osd.sh
              subPath: start_osd.sh
              readOnly: true
            - name: ceph-bin
              mountPath: /variables_entrypoint.sh
              subPath: variables_entrypoint.sh
              readOnly: true
            - name: ceph-bin
              mountPath: /common_functions.sh
              subPath: common_functions.sh
              readOnly: true
            - name: ceph-bin
              mountPath: /ceph-osd-liveness-readiness.sh
              subPath: ceph-osd-liveness-readiness.sh
              readOnly: true
            - name: ceph-etc
              mountPath: /etc/ceph/ceph.conf
              subPath: ceph.conf
              readOnly: true
            - name: ceph-client-admin-keyring
              mountPath: /etc/ceph/ceph.client.admin.keyring
              subPath: ceph.client.admin.keyring
              readOnly: false
            - name: ceph-mon-keyring
              mountPath: /etc/ceph/ceph.mon.keyring
              subPath: ceph.mon.keyring
              readOnly: false
            - name: ceph-bootstrap-osd-keyring
              mountPath: /var/lib/ceph/bootstrap-osd/ceph.keyring
              subPath: ceph.keyring
              readOnly: false
            - name: ceph-bootstrap-mds-keyring
              mountPath: /var/lib/ceph/bootstrap-mds/ceph.keyring
              subPath: ceph.keyring
              readOnly: false
            - name: ceph-bootstrap-rgw-keyring
              mountPath: /var/lib/ceph/bootstrap-rgw/ceph.keyring
              subPath: ceph.keyring
              readOnly: false
            - name: devices
              mountPath: /dev
              readOnly: false
            {{- if $value }}
            {{- if eq $value.type "device" }}
            - name: ceph-bin
              mountPath: /osd_disks.sh
              subPath: osd_disks.sh
              readOnly: true
            - name: ceph-bin
              mountPath: /osd_activate_journal.sh
              subPath: osd_activate_journal.sh
              readOnly: true
            - name: ceph-bin
              mountPath: /osd_disk_activate.sh
              subPath: osd_disk_activate.sh
              readOnly: true
            - name: ceph-bin
              mountPath: /osd_disk_prepare.sh
              subPath: osd_disk_prepare.sh
              readOnly: true
            # end of Device type check
            {{- end }}
            {{- else }}
            - name: ceph-bin
              mountPath: /osd_directory.sh
              subPath: osd_directory.sh
              readOnly: true
            - name: osd-directory
              mountPath: /var/lib/ceph/osd
              readOnly: false
            # end of Directory type check
            {{- end }}
          env:
            - name: CEPH_GET_ADMIN_KEY
              value: "1"
            {{- if $value }}
            {{- if eq $value.type "device" }}
            - name: CEPH_DAEMON
              value: osd_ceph_disk_activate
            - name: KV_TYPE
              value: k8s
            - name: CLUSTER
              value: ceph
            - name: OSD_DEVICE
              value: {{ $value.device }}
            {{ if $ctxt.Values.debug }}
            - name: DEBUG
              value: {{ $ctxt.Values.debug }}
            {{ end }}
            - name: HOSTNAME
              {{- if $value.hostname }}
              value: {{ $value.hostname }}
              {{- else }}
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
              {{- end }}
            {{- if $value.journal }}
            {{- if $value.journal | kindIs "string" }}
            - name: OSD_JOURNAL
              value: {{ $value.journal }}
            {{- else }}
            {{- if $value.journal.device }}
            - name: OSD_JOURNAL
              value: {{ $value.journal.device }}
            {{- end }}
            {{- if $value.journal.partition }}
            - name: OSD_JOURNAL_PARTITION
              value: {{ $value.journal.partition | quote }}
            {{- end }}
            {{- end }}
            {{- end }}
            # end of Device type check
            {{- end }}
            {{- else }}
            - name: CEPH_DAEMON
              value: osd_directory
            # end of Directory type check
            {{- end }}
          livenessProbe:
           exec:
            command:
             - /ceph-osd-liveness-readiness.sh
           initialDelaySeconds: 60
           periodSeconds: 60
          readinessProbe:
           exec:
            command:
             - /ceph-osd-liveness-readiness.sh
           initialDelaySeconds: 60
           periodSeconds: 60
      volumes:
        - name: devices
          hostPath:
            path: /dev
        - name: pod-var-lib-ceph
          emptyDir: {}
        - name: pod-run
          emptyDir:
            medium: "Memory"
        - name: ceph-bin
          configMap:
            name: ceph-bin
            defaultMode: 0555
        - name: ceph-etc
          configMap:
            name: ceph-etc
            defaultMode: 0444
        - name: ceph-client-admin-keyring
          secret:
            secretName: {{ $ctxt.Values.secrets.keyrings.admin }}
        - name: ceph-mon-keyring
          secret:
            secretName: {{ $ctxt.Values.secrets.keyrings.mon }}
        - name: ceph-bootstrap-osd-keyring
          secret:
            secretName: {{ $ctxt.Values.secrets.keyrings.osd }}
        - name: ceph-bootstrap-mds-keyring
          secret:
            secretName: {{ $ctxt.Values.secrets.keyrings.mds }}
        - name: ceph-bootstrap-rgw-keyring
          secret:
            secretName: {{ $ctxt.Values.secrets.keyrings.rgw }}
        {{- if not $value }}
        - name: ceph
          hostPath:
            path: {{ $ctxt.Values.ceph.storage.var_directory }}
        - name: osd-directory
          hostPath:
            path: {{ $ctxt.Values.ceph.storage.osd_directory }}
        # end of Directory type check
        {{- end }}
{{ end }}
