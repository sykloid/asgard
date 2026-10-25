local k = import '1.33/main.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'k8s/envoy-gateway',
  },
  spec: {
    namespace: 'envoy-gateway-system',
    resourceDefaults: {},
    expectVersions: {},
    contextNames: ['admin@asgard'],
  },
  data: {
    namespace: k.core.v1.namespace.new($.spec.namespace),
    // Single owner of the Gateway API CRDs (experimental channel, for TCPRoute) and Envoy Gateway's own CRDs.
    crds: helm.template('envoy-gateway-crds', 'charts/gateway-crds-helm', {
      namespace: $.spec.namespace,
      values: {
        crds: {
          gatewayAPI: {
            enabled: true,
            channel: 'experimental',
          },
          envoyGateway: {
            enabled: true,
          },
        },
      },
    }),
    envoyGateway: helm.template('envoy-gateway', 'charts/gateway-helm', {
      namespace: $.spec.namespace,
      values: {
        // CRDs come from gateway-crds-helm above.
        crds: {
          enabled: false,
        },
        // Zone labels for topology-aware routing; single-zone cluster.
        topologyInjector: {
          enabled: false,
        },
      },
    }),
  },
}
