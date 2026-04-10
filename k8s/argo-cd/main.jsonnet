local k = import '1.33/main.libsonnet';
local httpRoute = import 'asgard/http-route.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'k8s/argo-cd',
  },
  spec: {
    contextNames: [
      'admin@asgard',
    ],
    namespace: 'argo-cd',
    resourceDefaults: {},
    expectVersions: {},
  },
  data: {
    namespace: k.core.v1.namespace.new($.spec.namespace),
    argoCD: helm.template('argo-cd', 'charts/argo-cd', {
      namespace: $.spec.namespace,
      values: {
        namespaceOverride: 'argo-cd',
        fullnameOverride: 'argocd',
        configs: {
          cm: {
            url: 'https://argo-cd.asgard.sykloid.org',
            'kustomize.buildOptions': '--enable-helm',
            'oidc.config': std.manifestYamlDoc({
              name: 'Asgard SSO',
              issuer: 'https://pocket-id.asgard.sykloid.org',
              clientID: 'e35569b9-bc21-4459-aafc-bdd0cfac4554',
              enablePKCEAuthentication: true,
            }),
          },
          params: {
            'server.insecure': true,
          },
          rbac: {
            'policy.csv': |||
              g, admins, role:admin
            |||,
          },
        },
        server: {
          volumeMounts: [
            {
              name: 'asgard-root-ca-bundle',
              mountPath: '/etc/ssl/certs',
              readOnly: true,
            },
          ],
          volumes: [
            {
              name: 'asgard-root-ca-bundle',
              configMap: {
                name: 'asgard-root-ca-bundle',
                items: [
                  {
                    key: 'trust-bundle.pem',
                    path: 'asgard-root-ca-bundle.pem',
                  },
                ],
              },
            },
          ],
        },
        repoServer: {
          containerSecurityContext: {
            readOnlyRootFilesystem: false,
          },
          extraContainers: [
            {
              name: 'argocd-tanka-plugin',
              command: ['/var/run/argocd/argocd-cmp-server'],
              image: 'ghcr.io/sykloid/asgard/argocd-tanka-plugin:1.7',
              securityContext: {
                runAsNonRoot: true,
                runAsUser: 999,
              },
              volumeMounts: [
                {
                  name: 'var-files',
                  mountPath: '/var/run/argocd',
                },
                {
                  name: 'plugins',
                  mountPath: '/home/argocd/cmp-server/plugins',
                },
              ],
            },
          ],
        },
      },
    }),

    httpRoute: httpRoute.new('argocd-route', 'argo-cd.asgard.sykloid.org', 'argocd-server', 80),

    grpcRoute: {
      apiVersion: 'gateway.networking.k8s.io/v1',
      kind: 'GRPCRoute',
      metadata: {
        name: 'argocd-grpc-route',
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
        hostnames: ['argo-cd.asgard.sykloid.org'],
        rules: [
          {
            matches: [
              {
                headers: [
                  {
                    name: 'Content-Type',
                    type: 'RegularExpression',
                    value: '^application/grpc.*$',
                  },
                ],
              },
            ],
            backendRefs: [
              {
                group: '',
                kind: 'Service',
                name: 'argocd-server',
                port: 443,
                weight: 1,
              },
            ],
          },
        ],
      },
    },
  },
}
