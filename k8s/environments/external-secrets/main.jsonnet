local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local namespace = "external-secrets";

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'environments/external-secrets',
  },
  spec: {
    namespace: namespace,
    resourceDefaults: {},
    expectVersions: {},
    contextNames: ['admin@asgard'],
  },
  data: {
    namespace: {
      apiVersion: "v1",
      kind: "Namespace",
      metadata: {
        name: namespace
      }
    },
    externalSecrets: helm.template('external-secrets', 'charts/external-secrets', {
      namespace: 'external-secrets',
      values: {},
    }),
    asgardClusterSecretStore: import '1password-cluster-secret-store.jsonnet',
  },
}
