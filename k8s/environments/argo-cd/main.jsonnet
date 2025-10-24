local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

{
  'argo-cd': helm.template('argo-cd', 'charts/argo-cd', {
    namespace: 'argo-cd',
    values: {
      namespaceOverride: 'argo-cd',
      fullnameOverride: 'argocd',
      configs: {
        cm: {
          'kustomize.buildOptions': '--enable-helm',
        },
      },
      repoServer: {
        containerSecurityContext: {
          readOnlyRootFilesystem: false,
        },
        extraContainers: [
          {
            name: 'argocd-tanka-plugin',
            command: ['/var/run/argocd/argocd-cmp-server'],
            image: 'ghcr.io/sykloid/asgard/argocd-tanka-plugin:1.4',
            securityContext: {
              runAsNonRoot: true,
              runAsUser: 999,
            },
            volumeMounts: [
              {
                name: 'var-files',
                mountPath: '/var/run/argocd',
              },
              {
                name: 'plugins',
                mountPath: '/home/argocd/cmp-server/plugins',
              },
            ],
          },
        ],
      },
    },
  }),
}
