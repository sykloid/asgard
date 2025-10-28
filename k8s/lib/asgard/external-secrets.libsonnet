{
  new: function(name) {
    local base = self,
    secretRefs:: [],

    apiVersion: 'external-secrets.io/v1',
    kind: 'ExternalSecret',
    metadata: {
      name: name,
    },
    spec: {
      secretStoreRef: {
        kind: 'ClusterSecretStore',
        name: 'asgard-1password',
      },
      target: {
        creationPolicy: 'Owner',
      },
      data: [
        {
          secretKey: 'client_id',
          remoteRef: {
            key: 'tailscale-operator-client/username',
          },
        },
        {
          secretKey: 'client_secret',
          remoteRef: {
            key: 'tailscale-operator-client/credential',
          },
        },
      ],
    },
  },

  withSecret: function(secretKey, remoteKey) {
    secretRefs+: [
      {
        secretKey: secretKey,
        remoteRef: {
          key: remoteKey,
        }
      }
    ]
  }
}