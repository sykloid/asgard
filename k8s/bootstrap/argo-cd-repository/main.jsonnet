// Bootstrap environment for seeding the ArgoCD GitHub repository secret.
// Apply this once to create the argo-cd namespace and register the asgard
// repository with ArgoCD.
local k = import '1.33/main.libsonnet';

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'k8s/bootstrap/argo-cd-repository',
  },
  spec: {
    namespace: 'argo-cd',
    resourceDefaults: {},
    expectVersions: {},
  },
  data: {
    namespace: k.core.v1.namespace.new('argo-cd'),
    repository: k.core.v1.secret.new('asgard-github-repository', {})
                + k.core.v1.secret.withStringData({
                  name: 'asgard-github',
                  project: 'default',
                  type: 'git',
                  url: 'https://github.com/sykloid/asgard.git',
                })
                + k.core.v1.secret.metadata.withLabels({
                  'argocd.argoproj.io/secret-type': 'repository',
                }),
  },
}
