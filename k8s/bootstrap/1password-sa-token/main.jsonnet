// Bootstrap environment for seeding the 1Password service account token.
// Apply this once to create the external-secrets namespace and the SA token
// secret that the ClusterSecretStore references. The token value must be
// provided via the externalSecretsBootstrapToken parameter.
local k = import '1.33/main.libsonnet';

function(externalSecretsBootstrapToken='') {
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'k8s/bootstrap/1password-sa-token',
  },
  spec: {
    namespace: 'external-secrets',
    resourceDefaults: {},
    expectVersions: {},
  },
  data: {
    namespace: k.core.v1.namespace.new('external-secrets'),
    token: k.core.v1.secret.new('asgard-1password-sa-token', {
      token: std.base64(externalSecretsBootstrapToken),
    }),
  },
}
