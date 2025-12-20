local k = import '1.33/main.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'environments/argo-cd',
    namespace: 'environments/argo-cd/main.jsonnet',
  },
  spec: {
    contextNames: [
      'admin@asgard',
    ],
    namespace: 'argo-cd',
    resourceDefaults: {},
    expectVersions: {},
  },
  data: {
    namespace: k.core.v1.namespace.new($.spec.namespace),
    argoCD: helm.template('argo-cd', 'charts/argo-cd', {
      namespace: $.spec.namespace,
      values: {
        namespaceOverride: 'argo-cd',
        fullnameOverride: 'argocd',
        configs: {
          cm: {
            'kustomize.buildOptions': '--enable-helm',
          },
          params: {
            'server.insecure': true,
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
  },
}
