{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'environments/asgard',
  },
  spec: {
    namespace: 'argo-cd',
    resourceDefaults: {},
    expectVersions: {},
    contextNames: [
      'admin@asgard',
    ],
  },
  data: {
    argoCD: import 'argo-cd.jsonnet',
    cilium: import 'cilium.jsonnet',
    nfsProvisioner: import 'nfs-subdir-external-provisioner.jsonnet',
    externalSecrets: import 'external-secrets.jsonnet',
    tailscale: import 'tailscale.jsonnet',
  },
}
