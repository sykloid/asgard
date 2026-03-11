local k = import '1.33/main.libsonnet';
local es = import 'asgard/external-secrets.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'k8s/grafana',
  },
  spec: {
    namespace: 'grafana',
    resourceDefaults: {},
    expectVersions: {},
    contextNames: ['admin@asgard'],
  },
  data: {
    namespace: k.core.v1.namespace.new($.spec.namespace),

    secrets:
      es.new('grafana-secrets')
      + es.withSecret('admin-password', 'grafana-admin/password'),

    grafana: helm.template('grafana', 'charts/grafana', {
      namespace: $.spec.namespace,
      values: {
        fullnameOverride: 'grafana',
        deploymentStrategy: {
          type: 'Recreate',
        },
        admin: {
          existingSecret: 'grafana-secrets',
          passwordKey: 'admin-password',
        },
        persistence: {
          enabled: true,
          storageClassName: 'yggdrasil-iscsi-retain',
          size: '1Gi',
        },
        datasources: {
          'datasources.yaml': {
            apiVersion: 1,
            datasources: [
              {
                name: 'VictoriaMetrics',
                type: 'prometheus',
                access: 'proxy',
                url: 'http://vmsingle-asgard.monitoring:8428',
                isDefault: true,
              },
            ],
          },
        },
        'grafana.ini': {
          server: {
            root_url: 'https://grafana.asgard.sykloid.org',
          },
        },
      },
    }),

    httpRoute: {
      apiVersion: 'gateway.networking.k8s.io/v1',
      kind: 'HTTPRoute',
      metadata: {
        name: 'grafana-route',
      },
      spec: {
        parentRefs: [
          {
            group: 'gateway.networking.k8s.io',
            kind: 'Gateway',
            name: 'tailscale-secure-gateway',
            namespace: 'tailscale',
          },
        ],
        hostnames: ['grafana.asgard.sykloid.org'],
        rules: [
          {
            matches: [
              { path: { type: 'PathPrefix', value: '/' } },
            ],
            backendRefs: [
              {
                group: '',
                kind: 'Service',
                name: 'grafana',
                port: 80,
                weight: 1,
              },
            ],
          },
        ],
      },
    },
  },
}
