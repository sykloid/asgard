{
  new: function(name, env=null, namespace=null, project='asgard') {
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
          path: 'k8s/',
          plugin: {
            name: 'argocd-tanka-plugin-1.0',
            env: [
              {
                name: 'TK_ENV',
                value: if env == null then name else env,
              },
            ],
          },
        },
      ],
      destination: {
        server: 'https://kubernetes.default.svc',
        namespace: if namespace == null then name else namespace,
      },
      ignoreDifferences: base.ignoreDifferences,
      syncPolicy: {
        syncOptions: base.syncOptions,
      }
    },
  },
  withSyncOptions: function(syncOptions) {
    syncOptions+: syncOptions
  },
  withIgnoreDifferences: function(ignoreDifferences) {
    ignoreDifferences+: ignoreDifferences
  }
}
