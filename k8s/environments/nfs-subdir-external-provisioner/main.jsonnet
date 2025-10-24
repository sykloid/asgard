local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local NAS_IP = '192.168.1.3';
local NFS_SHARE_PATH = '/volume1/k8s';
local SC_NAME = 'yggdrasil';

function() {
  'nfs-subdir-external-provisioner': helm.template('nfs-subdir-external-provisioner', 'charts/nfs-subdir-external-provisioner', {
    namespace: 'nfs-subdir-external-provisioner',
    values: {
      nfs: {
        server: NAS_IP,
        path: NFS_SHARE_PATH,
      },
      storageClass: {
        name: SC_NAME,
      },
    },
  }),
}
