{
  apiVersion: 'external-secrets.io/v1',
  kind: 'ClusterSecretStore',
  metadata: {
    name: 'asgard-1password',
    namespace: 'external-secrets',
  },
  spec: {
    provider: {
      onepasswordSDK: {
        vault: 'asgard',
        auth: {
          serviceAccountSecretRef: {
            name: 'asgard-1password-sa-token',
            key: 'token',
            namespace: 'external-secrets',
          },
        },
      },
    },
  },
}
