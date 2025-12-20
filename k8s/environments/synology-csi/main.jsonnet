local es = import 'asgard/external-secrets.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local namespace = 'synology-csi';

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'environments/synology-csi',
  },
  spec: {
    namespace: namespace,
    resourceDefaults: {},
    expectVersions: {},
    contextNames: ['admin@asgard'],
  },
  data: {
    namespace: {
      apiVersion: 'v1',
      kind: 'Namespace',
      metadata: {
        name: namespace,
        labels: {
          'pod-security.kubernetes.io/enforce': 'privileged',
        },
      },
    },
    synologyCSI: helm.template('synology-csi', 'charts/synology-csi', {
      namespace: 'synology-csi',
      values: {
        storageClasses: {
          // Unclear why this needs to be present if this dictionary overrides builtin values.
          'synology-iscsi-storage': {
            disabled: true,
          },
          'yggdrasil-iscsi-retain': {
            reclaimPolicy: 'Retain',
            parameters: {
              dsm: '192.168.1.3',
              fsType: 'ext4',
              location: '/volume1',
            },
          },
          'yggdrasil-iscsi-delete': {
            reclaimPolicy: 'Delete',
            parameters: {
              dsm: '192.168.1.3',
              fsType: 'ext4',
              location: '/volume1',
            },
          },
        },
        test: {
          enabled: false,
        },
      },
    }),
    clientInfoSecret: es.new('client-info-secret') +
                      es.withSecret(
                        'client-info.yml',
                        'synology-csi-client-info/client-info.yml'
                      ),
  },
}
