local k = import '1.33/main.libsonnet';
local es = import 'asgard/external-secrets.libsonnet';

local container = k.core.v1.container;
local containerPort = k.core.v1.containerPort;
local deploy = k.apps.v1.deployment;
local pv = k.core.v1.persistentVolume;
local pvc = k.core.v1.persistentVolumeClaim;
local service = k.core.v1.service;
local servicePort = k.core.v1.servicePort;
local volume = k.core.v1.volume;
local volumeMount = k.core.v1.volumeMount;

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'k8s/paperless-ngx',
  },
  spec: {
    namespace: 'paperless-ngx',
    resourceDefaults: {},
    expectVersions: {},
    contextNames: ['admin@asgard'],
  },
  data: {
    namespace: k.core.v1.namespace.new($.spec.namespace),

    // --- Storage ---

    dataPvc:
      pvc.new('paperless-ngx-data')
      + pvc.spec.withAccessModes(['ReadWriteOnce'])
      + pvc.spec.withStorageClassName('yggdrasil-iscsi-retain')
      + pvc.spec.resources.withRequests({ storage: '1Gi' }),

    mediaPvc:
      pvc.new('paperless-ngx-media')
      + pvc.spec.withAccessModes(['ReadWriteOnce'])
      + pvc.spec.withStorageClassName('yggdrasil-iscsi-retain')
      + pvc.spec.resources.withRequests({ storage: '10Gi' }),

    consumePv:
      pv.new('paperless-ngx-consume')
      + pv.spec.withAccessModes(['ReadWriteMany'])
      + pv.spec.withCapacity({ storage: '1Gi' })
      + pv.spec.withMountOptions(['nfsvers=3'])
      + pv.spec.withStorageClassName('')
      + pv.spec.nfs.withServer('192.168.1.3')
      + pv.spec.nfs.withPath('/volume1/scanner'),

    consumePvc:
      pvc.new('paperless-ngx-consume')
      + pvc.spec.withAccessModes(['ReadWriteMany'])
      + pvc.spec.withStorageClassName('')
      + pvc.spec.withVolumeName('paperless-ngx-consume')
      + pvc.spec.resources.withRequests({ storage: '1Gi' }),

    // --- Secrets ---

    secrets:
      es.new('paperless-ngx-secrets')
      + es.withSecret('secret-key', 'paperless-ngx-secret-key/secret-key')
      + es.withSecret('client-id', 'paperless-ngx-oidc/client-id')
      + es.withSecret('client-secret', 'paperless-ngx-oidc/client-secret'),

    // --- Redis ---

    redisDeployment: deploy.new('redis', containers=[
      container.new('redis', 'redis:8')
      + container.withPorts([containerPort.new(6379)]),
    ]),

    redisService: service.new('redis', { name: 'redis' }, [
      servicePort.new(6379, 6379),
    ]),

    // --- Gotenberg ---

    gotenbergDeployment: deploy.new('gotenberg', containers=[
      container.new('gotenberg', 'gotenberg/gotenberg:8.26')
      + container.withPorts([containerPort.new(3000)])
      + container.withCommand([
        'gotenberg',
        '--chromium-disable-javascript=true',
        '--chromium-allow-list=file:///tmp/.*',
      ]),
    ]),

    gotenbergService: service.new('gotenberg', { name: 'gotenberg' }, [
      servicePort.new(3000, 3000),
    ]),

    // --- Tika ---

    tikaDeployment: deploy.new('tika', containers=[
      container.new('tika', 'apache/tika:3.2.3.0')
      + container.withPorts([containerPort.new(9998)]),
    ]),

    tikaService: service.new('tika', { name: 'tika' }, [
      servicePort.new(9998, 9998),
    ]),

    // --- Paperless-ngx ---

    deployment: deploy.new('paperless-ngx', containers=[
                  container.new('paperless-ngx', 'ghcr.io/paperless-ngx/paperless-ngx:2.20.8')
                  + container.withPorts([containerPort.new(8000)])
                  + container.withEnvMap({
                    PAPERLESS_URL: 'https://paperless.asgard.sykloid.org',
                    PAPERLESS_REDIS: 'redis://redis:6379',
                    PAPERLESS_TIKA_ENABLED: '1',
                    PAPERLESS_TIKA_ENDPOINT: 'http://tika:9998',
                    PAPERLESS_TIKA_GOTENBERG_ENDPOINT: 'http://gotenberg:3000',
                    PAPERLESS_CONSUMER_POLLING: '60',
                    PAPERLESS_OCR_LANGUAGE: 'eng',
                    PAPERLESS_TIME_ZONE: 'Etc/UTC',
                    REQUESTS_CA_BUNDLE: '/etc/ssl/certs/ca-certificates.crt',
                    PAPERLESS_APPS: 'allauth.socialaccount.providers.openid_connect',
                    PAPERLESS_SECRET_KEY: {
                      secretKeyRef: {
                        name: 'paperless-ngx-secrets',
                        key: 'secret-key',
                      },
                    },
                    OIDC_CLIENT_ID: {
                      secretKeyRef: {
                        name: 'paperless-ngx-secrets',
                        key: 'client-id',
                      },
                    },
                    OIDC_CLIENT_SECRET: {
                      secretKeyRef: {
                        name: 'paperless-ngx-secrets',
                        key: 'client-secret',
                      },
                    },
                    PAPERLESS_SOCIALACCOUNT_PROVIDERS: std.manifestJsonMinified({
                      openid_connect: {
                        OAUTH_PKCE_ENABLED: true,
                        APPS: [{
                          provider_id: 'pocket-id',
                          name: 'Asgard SSO',
                          client_id: '$(OIDC_CLIENT_ID)',
                          secret: '$(OIDC_CLIENT_SECRET)',
                          settings: {
                            server_url: 'https://pocket-id.asgard.sykloid.org/.well-known/openid-configuration',
                          },
                        }],
                      },
                    }),
                  })
                  + container.withVolumeMounts([
                    volumeMount.new('data', '/usr/src/paperless/data'),
                    volumeMount.new('media', '/usr/src/paperless/media'),
                    volumeMount.new('consume', '/usr/src/paperless/consume'),
                    volumeMount.new('ca-bundle', '/etc/ssl/certs', readOnly=true),
                  ]),
                ])
                + deploy.spec.template.spec.withVolumes([
                  volume.fromPersistentVolumeClaim('data', 'paperless-ngx-data'),
                  volume.fromPersistentVolumeClaim('media', 'paperless-ngx-media'),
                  volume.fromPersistentVolumeClaim('consume', 'paperless-ngx-consume'),
                  volume.fromConfigMap('ca-bundle', 'asgard-root-ca-bundle', [
                    k.core.v1.keyToPath.new('trust-bundle.pem', 'ca-certificates.crt'),
                  ]),
                ]),

    service: service.new('paperless-ngx', { name: 'paperless-ngx' }, [
      servicePort.new(8000, 8000),
    ]),

    // --- HTTPRoute ---

    httpRoute: {
      apiVersion: 'gateway.networking.k8s.io/v1',
      kind: 'HTTPRoute',
      metadata: {
        name: 'paperless-ngx-route',
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
        hostnames: ['paperless.asgard.sykloid.org'],
        rules: [
          {
            matches: [
              { path: { type: 'PathPrefix', value: '/' } },
            ],
            backendRefs: [
              {
                group: '',
                kind: 'Service',
                name: 'paperless-ngx',
                port: 8000,
                weight: 1,
              },
            ],
          },
        ],
      },
    },
  },
}
