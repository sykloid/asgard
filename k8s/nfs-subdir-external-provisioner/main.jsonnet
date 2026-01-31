local k = import '1.33/main.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local NAS_IP = '192.168.1.3';
local NFS_SHARE_PATH = '/volume1/k8s';
local SC_NAME = 'yggdrasil-nfs';

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'k8s/nfs-subdir-external-provisioner',
    namespace: 'environments/nfs-subdir-external-provisioner/main.jsonnet',
  },
  spec: {
    contextNames: [
      'admin@asgard',
    ],
    namespace: 'nfs-subdir-external-provisioner',
    resourceDefaults: {},
    expectVersions: {},
  },
  data: {
    namespace: k.core.v1.namespace.new($.spec.namespace),
    'nfs-subdir-external-provisioner-delete': helm.template('nfs-subdir-external-provisioner', 'charts/nfs-subdir-external-provisioner', {
      namespace: 'nfs-subdir-external-provisioner',
      values: {
        nfs: {
          server: NAS_IP,
          path: NFS_SHARE_PATH,
        },
        storageClass: {
          name: (SC_NAME + '-delete'),
          reclaimPolicy: 'Delete',
        },
      },
    }),
    'nfs-subdir-external-provisioner-retain': helm.template('nfs-subdir-external-provisioner', 'charts/nfs-subdir-external-provisioner', {
      namespace: 'nfs-subdir-external-provisioner',
      values: {
        nfs: {
          server: NAS_IP,
          path: NFS_SHARE_PATH,
        },
        storageClass: {
          name: (SC_NAME + '-retain'),
          reclaimPolicy: 'Retain',
        },
      },
    }),
  },
}
