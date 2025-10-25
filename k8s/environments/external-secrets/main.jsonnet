local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'environments/external-secrets',
  },
  spec: {
    namespace: 'default',
    resourceDefaults: {},
    expectVersions: {},
    contextNames: ['admin@asgard'],
  },
  data: {
    externalSecrets: helm.template('external-secrets', 'charts/external-secrets', {
      namespace: 'external-secrets',
      values: {},
    }),
    asgardClusterSecretStore: import '1password-cluster-secret-store.jsonnet',
  },
}
