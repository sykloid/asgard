local k = import '1.33/main.libsonnet';
local es = import 'asgard/external-secrets.libsonnet';
local httpRoute = import 'asgard/http-route.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'k8s/grafana',
  },
  spec: {
    namespace: 'grafana',
    resourceDefaults: {},
    expectVersions: {},
    contextNames: ['admin@asgard'],
  },
  data: {
    namespace: k.core.v1.namespace.new($.spec.namespace),

    secrets:
      es.new('grafana-secrets')
      + es.withSecret('admin-user', 'grafana-admin/username')
      + es.withSecret('admin-password', 'grafana-admin/password')
      + es.withSecret('oidc-client-id', 'grafana-oidc/client-id')
      + es.withSecret('oidc-client-secret', 'grafana-oidc/client-secret'),

    grafana: helm.template('grafana', 'charts/grafana', {
      namespace: $.spec.namespace,
      values: {
        fullnameOverride: 'grafana',
        deploymentStrategy: {
          type: 'Recreate',
        },
        admin: {
          existingSecret: 'grafana-secrets',
          passwordKey: 'admin-password',
        },
        persistence: {
          enabled: true,
          storageClassName: 'yggdrasil-iscsi-retain',
          size: '1Gi',
        },
        datasources: {
          'datasources.yaml': {
            apiVersion: 1,
            datasources: [
              {
                name: 'VictoriaMetrics',
                type: 'prometheus',
                access: 'proxy',
                url: 'http://vmsingle-asgard.monitoring:8428',
                isDefault: true,
              },
            ],
          },
        },
        envFromSecrets: [
          { name: 'grafana-secrets', optional: false },
        ],
        extraVolumeMounts: [
          {
            name: 'ca-bundle',
            mountPath: '/etc/ssl/certs/asgard-root-ca.pem',
            subPath: 'trust-bundle.pem',
            readOnly: true,
          },
        ],
        extraVolumes: [
          {
            name: 'ca-bundle',
            configMap: {
              name: 'asgard-root-ca-bundle',
            },
          },
        ],
        'grafana.ini': {
          server: {
            root_url: 'https://grafana.asgard.sykloid.org',
          },
          'auth.generic_oauth': {
            enabled: true,
            name: 'Asgard SSO',
            client_id: '$__env{oidc-client-id}',
            client_secret: '$__env{oidc-client-secret}',
            scopes: 'openid email profile groups',
            auth_url: 'https://pocket-id.asgard.sykloid.org/authorize',
            token_url: 'https://pocket-id.asgard.sykloid.org/api/oidc/token',
            api_url: 'https://pocket-id.asgard.sykloid.org/api/oidc/userinfo',
            role_attribute_path: "contains(groups[*], 'admins') && 'Admin' || 'Viewer'",
            allow_sign_up: true,
            tls_client_ca: '/etc/ssl/certs/asgard-root-ca.pem',
          },
        },
      },
    }),

    httpRoute: httpRoute.new('grafana-route', 'grafana.asgard.sykloid.org', 'grafana', 80),
  },
}
