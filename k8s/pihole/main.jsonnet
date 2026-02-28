local k = import '1.33/main.libsonnet';
local es = import 'asgard/external-secrets.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'k8s/pihole',
  },
  spec: {
    namespace: 'pihole',
    resourceDefaults: {},
    expectVersions: {},
    contextNames: ['admin@asgard'],
  },
  data: {
    namespace: k.core.v1.namespace.new($.spec.namespace),
    pihole: helm.template('pihole', 'charts/pihole', {
      namespace: $.spec.namespace,
      values: {
        admin: {
          existingSecret: 'pihole-credentials',
          passwordKey: 'password',
        },
        serviceDns: {
          mixedService: true,
          type: 'LoadBalancer',
          loadBalancerClass: 'tailscale',
          annotations: {
            'tailscale.com/hostname': 'asgard-pihole-dns',
          },
        },
        extraEnvVars: {
          FTLCONF_dns_listeningMode: 'all',
        },
      },
    }),
    piholeCredentials: es.new('pihole-credentials') +
                       es.withSecret(
                         'password',
                         'pihole-admin-password/password'
                       ),

    httpRoute: {
      apiVersion: 'gateway.networking.k8s.io/v1',
      kind: 'HTTPRoute',
      metadata: {
        name: 'pihole-route',
      },
      spec: {
        parentRefs: [
          {
            group: 'gateway.networking.k8s.io',
            kind: 'Gateway',
            name: 'tailscale-secure-gateway',
            namespace: 'tailscale',
          },
        ],
        hostnames: ['pihole.asgard.sykloid.org'],
        rules: [
          {
            matches: [
              { path: { type: 'PathPrefix', value: '/' } },
            ],
            backendRefs: [
              {
                group: '',
                kind: 'Service',
                name: 'pihole-web',
                port: 80,
                weight: 1,
              },
            ],
          },
        ],
      },
    },
  },
}
