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
      refreshInterval: '1h',
      target: {
        creationPolicy: 'Owner',
        deletionPolicy: 'Retain',
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
          conversionStrategy: 'Default',
          decodingStrategy: 'None',
          metadataPolicy: 'None',
        }
      }
    ]
  }
}
