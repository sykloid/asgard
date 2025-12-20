local k = import "1.33/main.libsonnet";
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);
local es = import 'asgard/external-secrets.libsonnet';

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'environments/external-dns',
  },
  spec: {
    namespace: 'external-dns',
    resourceDefaults: {},
    expectVersions: {},
    contextNames: ['admin@asgard'],
  },
  data: {
    namespace: k.core.v1.namespace.new($.spec.namespace),
    externalDNS: helm.template('external-dns', 'charts/external-dns', {
      namespace: $.spec.namespace,
      values: {
        provider: 'pihole',
        extraArgs: [
          '--pihole-server=http://pihole-web.pihole',
          '--pihole-api-version=6',
          '--gateway-label-filter=external-dns==enabled',
        ],
        policy: 'sync',
        sources: [
          'gateway-httproute'
        ],
        domainFilters: [
          'asgard.sykloid.org',
        ],
        env: [
          {
            name: 'EXTERNAL_DNS_PIHOLE_PASSWORD',
            valueFrom: {
              secretKeyRef: {
                name: 'external-dns-pihole-credentials',
                key: 'password',
              }
            }
          }
        ]
      }
    }),
    piholeCredentials: es.new('external-dns-pihole-credentials') +
                       es.withSecret(
                         'password',
                         'pihole-admin-password/password'
                       ),
  },
}
