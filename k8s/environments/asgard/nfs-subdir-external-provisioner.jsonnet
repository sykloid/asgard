{
  apiVersion: 'argoproj.io/v1alpha1',
  kind: 'Application',
  metadata: {
    name: 'nfs-subdir-external-provisioner',
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
              value: 'nfs-subdir-external-provisioner',
            },
          ],
        },
      },
    ],
    destination: {
      server: 'https://kubernetes.default.svc',
      namespace: 'nfs-subdir-external-provisioner',
    },
  },
}
