{
  apiVersion: 'argoproj.io/v1alpha1',
  kind: 'Application',
  metadata: {
    name: 'cilium',
    namespace: 'argo-cd',
  },
  spec: {
    project: 'asgard',
    sources: [
      {
        repoURL: 'https://github.com/sykloid/asgard.git',
        targetRevision: 'master',
        path: 'k8s/',
        plugin: {
          name: 'argocd-tanka-plugin-1.0',
          env: [
            {
              name: 'TK_ENV',
              value: 'cilium',
            },
          ],
        },
      },
    ],
    ignoreDifferences: [
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
    ],
    destination: {
      server: 'https://kubernetes.default.svc',
      namespace: 'kube-system',
    },
  },
}
