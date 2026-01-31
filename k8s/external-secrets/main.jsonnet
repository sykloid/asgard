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
      values: {},
    }),
    asgardClusterSecretStore: import '1password-cluster-secret-store.jsonnet',
  },
}
