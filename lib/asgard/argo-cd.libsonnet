{
  project: {
    new: function(name) {

    }
  },
  application: {
    new: function(name, env=null, namespace=null, project='default') {
      local base = self,
      ignoreDifferences:: [],
      syncOptions:: [],

      apiVersion: 'argoproj.io/v1alpha1',
      kind: 'Application',
      metadata: {
        name: name,
        namespace: 'argo-cd',
      },
      spec: {
        project: project,
        sources: [
          {
            repoURL: 'https://github.com/sykloid/asgard.git',
            targetRevision: 'master',
            path: '.',
            plugin: {
              name: 'argocd-tanka-plugin-1.0',
              env: [
                {
                  name: 'TK_ENV',
                  value: if env == null then 'k8s/' + name else env,
                },
              ],
            },
          },
        ],
        destination: {
          server: 'https://kubernetes.default.svc',
          namespace: if namespace == null then name else namespace,
        },
        [if base.ignoreDifferences != [] then 'ignoreDifferences']: base.ignoreDifferences,
        [if base.syncOptions != [] then 'syncPolicy']: {
          syncOptions: base.syncOptions,
        },
      },
    },
    withSyncOptions: function(syncOptions) {
      syncOptions+: syncOptions,
    },
    withIgnoreDifferences: function(ignoreDifferences) {
      ignoreDifferences+: ignoreDifferences,
    },
  },
}
