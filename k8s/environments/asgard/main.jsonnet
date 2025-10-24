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
    argoCDApplication: import 'argo-cd-application.jsonnet',
    cilium: import 'cilium.jsonnet',
  },
}
