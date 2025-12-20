local argoCD = import 'asgard/argo-cd.libsonnet';

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
    argoCD: argoCD.new('argo-cd'),
    cilium: argoCD.new('cilium', namespace='kube-system') + argoCD.withIgnoreDifferences([
      {
        jsonPointers: [
          '/data/ca.crt',
        ],
        kind: 'ConfigMap',
        name: 'hubble-ca-cert',
      },
      {
        jsonPointers: [
          '/data/ca.crt',
          '/data/ca.key',
        ],
        kind: 'Secret',
        name: 'cilium-ca',
      },
      {
        jsonPointers: [
          '/data/ca.crt',
          '/data/tls.crt',
          '/data/tls.key',
        ],
        kind: 'Secret',
        name: 'hubble-relay-client-certs',
      },
      {
        jsonPointers: [
          '/data/ca.crt',
          '/data/tls.crt',
          '/data/tls.key',
        ],
        kind: 'Secret',
        name: 'hubble-server-certs',
      },
    ]),
    nfsProvisioner: argoCD.new('nfs-subdir-external-provisioner'),
    externalSecrets: argoCD.new('external-secrets') + argoCD.withSyncOptions(['ServerSideApply=true']),
    tailscale: argoCD.new('tailscale'),
    synologyCSI: argoCD.new('synology-csi'),
    pihole: argoCD.new('pihole'),
  },
}
