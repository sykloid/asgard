local k = import '1.33/main.libsonnet';
local es = import 'asgard/external-secrets.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'environments/synology-csi',
  },
  spec: {
    namespace: 'synology-csi',
    resourceDefaults: {},
    expectVersions: {},
    contextNames: ['admin@asgard'],
  },
  data: {
    namespace: k.core.v1.namespace.new($.spec.namespace),
    synologyCSI: helm.template('synology-csi', 'charts/synology-csi', {
      namespace: $.spec.namespace,
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
