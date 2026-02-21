local k = import '1.33/main.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);
local es = import 'asgard/external-secrets.libsonnet';

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'k8s/cert-manager',
  },
  spec: {
    namespace: 'cert-manager',
    resourceDefaults: {},
    expectVersions: {},
    contextNames: ['admin@asgard'],
  },
  data: {
    namespace: k.core.v1.namespace.new($.spec.namespace),
    certManager: helm.template('cert-manager', 'charts/cert-manager', {
      namespace: $.spec.namespace,
      values: {
        crds: {
          enabled: true,
        },
        config: {
          enableGatewayAPI: true,
          featureGates: {
            NameConstraints: true,
          },
        },
        webhook: {
          featureGates: 'NameConstraints=true',
        },
        podDisruptionBudget: {
          enabled: true,
        },
      },
    }),

    trustManager: helm.template('trust-manager', 'charts/trust-manager', {
      namespace: 'cert-manager',
      values: {
      },
    }),

    // Rehydrate the root CA certificate from 1Password rather than bootstrapping
    // a new one. The issuer below then generates certificates signed by it.
    rootCASecret: es.new('asgard-root-ca-secret')
                  + es.withSecret('tls.crt', 'asgard-root-ca/tls.crt')
                  + es.withSecret('tls.key', 'asgard-root-ca/tls.key')
                  + es.withSecret('ca.crt', 'asgard-root-ca/ca.crt'),

    rootCAIssuer: {
      apiVersion: 'cert-manager.io/v1',
      kind: 'ClusterIssuer',
      metadata: {
        name: 'asgard-root-ca-issuer',
      },
      spec: {
        ca: {
          secretName: 'asgard-root-ca-secret',
        },
      },
    },

    // Create a trust bundle in each namespace (in the form of a configmap) which
    // contains the information necessary to allow pods to trust certificates
    // signed by our root CA.
    trustBundle: {
      apiVersion: 'trust.cert-manager.io/v1alpha1',
      kind: 'Bundle',
      metadata: {
        name: 'asgard-root-ca-bundle',
      },
      spec: {
        sources: [
          { useDefaultCAs: true },
          { secret: { name: 'asgard-root-ca-secret', key: 'tls.crt' } },
        ],
        target: { configMap: { key: 'trust-bundle.pem' } },
      },
    },
  },
}
