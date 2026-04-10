local k = import '1.33/main.libsonnet';
local es = import 'asgard/external-secrets.libsonnet';
local httpRoute = import 'asgard/http-route.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local sa = k.core.v1.serviceAccount;

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'k8s/argo-workflows',
  },
  spec: {
    namespace: 'argo-workflows',
    resourceDefaults: {},
    expectVersions: {},
    contextNames: ['admin@asgard'],
  },
  data: {
    namespace: k.core.v1.namespace.new($.spec.namespace),

    secrets:
      es.new('argo-workflows-sso')
      + es.withSecret('client-id', 'argo-workflows-oidc/client-id')
      + es.withSecret('client-secret', 'argo-workflows-oidc/client-secret'),

    'argo-workflows': helm.template('argo-workflows', 'charts/argo-workflows', {
      namespace: $.spec.namespace,
      values: {
        workflow: {
          serviceAccount: {
            create: false,
            name: 'default',
          },
          rbac: {
            create: true,
          },
        },
        controller: {
          workflowNamespaces: [$.spec.namespace],
        },
        server: {
          authModes: ['sso'],
          sso: {
            enabled: true,
            issuer: 'https://pocket-id.asgard.sykloid.org',
            clientId: {
              name: 'argo-workflows-sso',
              key: 'client-id',
            },
            clientSecret: {
              name: 'argo-workflows-sso',
              key: 'client-secret',
            },
            redirectUrl: 'https://argo-workflows.asgard.sykloid.org/oauth2/callback',
            scopes: ['openid', 'email', 'profile', 'groups'],
            rbac: {
              enabled: true,
            },
            insecureSkipVerify: true,
          },
        },
      },
    }),

    // --- SSO RBAC ---

    adminSa:
      sa.new('argo-workflows-admin')
      + sa.metadata.withAnnotations({
        'workflows.argoproj.io/rbac-rule': "'admins' in groups",
        'workflows.argoproj.io/rbac-rule-precedence': '1',
      }),

    adminSaToken: {
      apiVersion: 'v1',
      kind: 'Secret',
      metadata: {
        name: 'argo-workflows-admin.service-account-token',
        annotations: {
          'kubernetes.io/service-account.name': 'argo-workflows-admin',
        },
      },
      type: 'kubernetes.io/service-account-token',
    },

    adminRole: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRole',
      metadata: {
        name: 'argo-workflows-admin-sso',
      },
      rules: [
        {
          apiGroups: ['argoproj.io'],
          resources: [
            'workflows',
            'workflows/finalizers',
            'workfloweventbindings',
            'workflowtemplates',
            'cronworkflows',
            'clusterworkflowtemplates',
            'workflowtasksets',
            'workflowtaskresults',
            'workflowartifactgctasks',
          ],
          verbs: ['create', 'delete', 'deletecollection', 'get', 'list', 'patch', 'update', 'watch'],
        },
        {
          apiGroups: [''],
          resources: ['pods', 'pods/log', 'events', 'configmaps'],
          verbs: ['get', 'list', 'watch'],
        },
        {
          apiGroups: [''],
          resources: ['secrets'],
          verbs: ['get'],
        },
      ],
    },

    adminRoleBinding: {
      apiVersion: 'rbac.authorization.k8s.io/v1',
      kind: 'ClusterRoleBinding',
      metadata: {
        name: 'argo-workflows-admin-sso',
      },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'ClusterRole',
        name: 'argo-workflows-admin-sso',
      },
      subjects: [
        {
          kind: 'ServiceAccount',
          name: 'argo-workflows-admin',
          namespace: 'argo-workflows',
        },
      ],
    },

    httpRoute: httpRoute.new('argo-workflows-route', 'argo-workflows.asgard.sykloid.org', 'argo-workflows-server', 2746),
  },
}
