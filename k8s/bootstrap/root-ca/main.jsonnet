// Bootstrap environment for generating the root CA certificate.
// Apply this once, save the generated asgard-root-ca-secret to 1Password,
// then delete both resources. The cert-manager environment rehydrates the
// secret via ExternalSecret for ongoing use.
{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'k8s/bootstrap/root-ca',
  },
  spec: {
    namespace: 'cert-manager',
    resourceDefaults: {},
    expectVersions: {},
  },
  data: {
    selfSignedIssuer: {
      apiVersion: 'cert-manager.io/v1',
      kind: 'ClusterIssuer',
      metadata: {
        name: 'asgard-self-signed-issuer',
      },
      spec: {
        selfSigned: {},
      },
    },
    rootCACertificate: {
      apiVersion: 'cert-manager.io/v1',
      kind: 'Certificate',
      metadata: {
        name: 'asgard-root-ca',
        namespace: 'cert-manager',
      },
      spec: {
        isCA: true,
        commonName: 'asgard-root-ca',
        secretName: 'asgard-root-ca-secret',
        duration: '87600h',  // 10y
        renewBefore: '78840h',  // 9y
        privateKey: {
          algorithm: 'ECDSA',
          size: 256,
        },
        issuerRef: {
          name: 'asgard-self-signed-issuer',
          kind: 'ClusterIssuer',
          group: 'cert-manager.io',
        },
      },
    },
  },
}
