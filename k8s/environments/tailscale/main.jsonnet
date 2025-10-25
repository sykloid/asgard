local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'environments/tailscale',
  },
  spec: {
    namespace: 'default',
    resourceDefaults: {},
    expectVersions: {},
    contextNames: [
      'admin@asgard',
    ],
  },
  data: {
    tailscaleOperator: helm.template('tailscale', 'charts/tailscale-operator', {
      namespace: 'tailscale',
      values: {
        operatorConfig: {
          defaultTags: [
            'tag:asgard-tailscale-operator',
          ],
        },
        proxyConfig: {
          defaultTags: 'tag:asgard-service',
        },
        apiServerProxyConfig: {
          mode: 'noauth',
        },
      },
    }),
    oauthSecret: {
      apiVersion: 'external-secrets.io/v1',
      kind: 'ExternalSecret',
      metadata: {
        name: 'operator-oauth',
        namespace: 'tailscale',
      },
      spec: {
        secretStoreRef: {
          kind: 'ClusterSecretStore',
          name: 'asgard-1password',
        },
        target: {
          creationPolicy: 'Owner',
        },
        data: [
          {
            secretKey: 'client_id',
            remoteRef: {
              key: 'tailscale-operator-client/username',
            },
          },
          {
            secretKey: 'client_secret',
            remoteRef: {
              key: 'tailscale-operator-client/credential',
            },
          },
        ],
      },
    },
  },
}
