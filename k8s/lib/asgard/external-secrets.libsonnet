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
      data: base.secretRefs,
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
