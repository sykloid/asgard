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
    argoCD: argoCD.application.new('argo-cd'),
    cilium: argoCD.application.new('cilium', namespace='kube-system') + argoCD.application.withIgnoreDifferences([
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
    nfsProvisioner: argoCD.application.new('nfs-subdir-external-provisioner'),
    externalSecrets: argoCD.application.new('external-secrets') +
                     argoCD.application.withSyncOptions(['ServerSideApply=true']),
    certManager: argoCD.application.new('cert-manager'),
    tailscale: argoCD.application.new('tailscale'),
    synologyCSI: argoCD.application.new('synology-csi'),
    pihole: argoCD.application.new('pihole'),
    externalDNS: argoCD.application.new('external-dns'),
    pocketID: argoCD.application.new('pocket-id') +
              argoCD.application.withSyncOptions(['ServerSideApply=true']) +
              argoCD.application.withIgnoreDifferences([
                {
                  group: 'apps',
                  kind: 'StatefulSet',
                  name: 'pocket-id',
                  jsonPointers: [
                    '/spec/updateStrategy/rollingUpdate/maxUnavailable',
                  ],
                },
              ]),
  },
}
