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
        testFramework: {
          enabled: false,
        },
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
        // VictoriaLogs datasource (logs + k8s events live in the same vlsingle
        // instance) requires its signed plugin from the Grafana catalog.
        plugins: ['victoriametrics-logs-datasource'],
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
              {
                name: 'VictoriaLogs',
                type: 'victoriametrics-logs-datasource',
                access: 'proxy',
                url: 'http://vlsingle-asgard.monitoring:9428',
                jsonData: {
                  // Map the OTLP `severity` field (set by the otel-collector's
                  // severity parsing) to Grafana log levels so the logs
                  // histogram stacks by level instead of showing "unknown".
                  // This is the provisioning equivalent of the datasource's
                  // "OpenTelemetry preset" (a UI-only toggle). Case-insensitive
                  // regex also folds e.g. INFO and info into one level. First
                  // matching rule wins; values that match nothing (e.g.
                  // "Unspecified" plaintext) stay unknown, which is correct.
                  // The otel-collector canonicalizes `severity` to a fixed set
                  // (trace/debug/info/warn/error/critical) regardless of source
                  // log format, so these are simple exact matches.
                  logLevelRules: [
                    { field: 'severity', operator: 'equals', value: 'critical', level: 'critical', enabled: true },
                    { field: 'severity', operator: 'equals', value: 'error', level: 'error', enabled: true },
                    { field: 'severity', operator: 'equals', value: 'warn', level: 'warning', enabled: true },
                    { field: 'severity', operator: 'equals', value: 'info', level: 'info', enabled: true },
                    { field: 'severity', operator: 'equals', value: 'debug', level: 'debug', enabled: true },
                    { field: 'severity', operator: 'equals', value: 'trace', level: 'trace', enabled: true },
                  ],
                },
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
          auth: {
            disable_login_form: true,
            oauth_auto_login: true,
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
