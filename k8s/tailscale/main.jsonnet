local k = import '1.33/main.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);
local es = import 'asgard/external-secrets.libsonnet';

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'k8s/tailscale',
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
      'pod-security.kubernetes.io/enforce': 'privileged',
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
                 + es.withSecret('client_secret', 'tailscale-operator-client/credential'),

    gatewayClass: {
      apiVersion: 'gateway.networking.k8s.io/v1',
      kind: 'GatewayClass',
      metadata: {
        name: 'tailscale-gateway-class',
      },
      spec: {
        controllerName: 'io.cilium/gateway-controller',
        parametersRef: {
          group: 'cilium.io',
          kind: 'CiliumGatewayClassConfig',
          name: 'tailscale-gateway-config',
          namespace: 'tailscale',
        },
      },
    },

    gatewayClassConfig: {
      apiVersion: 'cilium.io/v2alpha1',
      kind: 'CiliumGatewayClassConfig',
      metadata: {
        name: 'tailscale-gateway-config',
        namespace: 'tailscale',
      },
      spec: {
        service: {
          type: 'LoadBalancer',
          loadBalancerClass: 'tailscale',
        },
      },
    },

    wildcardCert: {
      apiVersion: 'cert-manager.io/v1',
      kind: 'Certificate',
      metadata: {
        name: 'asgard-sykloid-org-tls',
        labels: {
          'external-dns': 'enabled',
        },
      },
      spec: {
        issuerRef: {
          name: 'asgard-root-ca-issuer',
          kind: 'ClusterIssuer',
          group: 'cert-manager.io',
        },
        dnsNames: ['*.asgard.sykloid.org'],
        secretName: 'asgard-sykloid-org-tls',
      },
    },

    gateway: {
      apiVersion: 'gateway.networking.k8s.io/v1',
      kind: 'Gateway',
      metadata: {
        name: 'tailscale-secure-gateway',
        namespace: 'tailscale',
        annotations: {
          'cert-manager.io/cluster-issuer': 'asgard-root-ca-issuer',
        },
        labels: {
          'external-dns': 'enabled',
        },
      },
      spec: {
        gatewayClassName: 'tailscale-gateway-class',
        infrastructure: {
          annotations: {
            'tailscale.com/hostname': 'asgard-secure-gateway',
          },
        },
        listeners: [
          {
            name: 'https',
            protocol: 'HTTPS',
            port: 443,
            hostname: '*.asgard.sykloid.org',
            allowedRoutes: {
              namespaces: {
                from: 'All',
              },
            },
            tls: {
              mode: 'Terminate',
              certificateRefs: [
                { group: '', kind: 'Secret', name: 'asgard-sykloid-org-tls' },
              ],
            },
          },
        ],
      },
    },
  },
}
