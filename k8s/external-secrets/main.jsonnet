local k = import '1.33/main.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'k8s/external-secrets',
  },
  spec: {
    namespace: 'external-secrets',
    resourceDefaults: {},
    expectVersions: {},
    contextNames: ['admin@asgard'],
  },
  data: {
    namespace: k.core.v1.namespace.new($.spec.namespace),
    externalSecrets: helm.template('external-secrets', 'charts/external-secrets', {
      namespace: 'external-secrets',
      values: {
        // Webhook cert from cert-manager instead of the chart's cert-controller.
        webhook: {
          certManager: {
            enabled: true,
            cert: {
              issuerRef: {
                group: 'cert-manager.io',
                kind: 'ClusterIssuer',
                name: 'asgard-root-ca-issuer',
              },
            },
          },
        },
        certController: {
          create: false,
        },
      },
    }),
    asgardClusterSecretStore: import '1password-cluster-secret-store.jsonnet',
  },
}
