local k = import '1.33/main.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);
local es = import 'asgard/external-secrets.libsonnet';

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'environments/tailscale',
  },
  spec: {
    namespace: 'tailscale',
    resourceDefaults: {},
    expectVersions: {},
    contextNames: [
      'admin@asgard',
    ],
  },
  data: {
    namespace: k.core.v1.namespace.new($.spec.namespace) + k.core.v1.namespace.metadata.withLabels({
      "pod-security.kubernetes.io/enforce": "privileged",
    }),
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
    oauthSecret: es.new('operator-oauth')
               + es.withSecret('client_id', 'tailscale-operator-client/username')
               + es.withSecret('client_secret', 'tailscale-operator-client/credential')
  },
}
