local k = import '1.33/main.libsonnet';
local es = import 'asgard/external-secrets.libsonnet';
local httpRoute = import 'asgard/http-route.libsonnet';

local container = k.core.v1.container;
local containerPort = k.core.v1.containerPort;
local deploy = k.apps.v1.deployment;
local pvc = k.core.v1.persistentVolumeClaim;
local service = k.core.v1.service;
local servicePort = k.core.v1.servicePort;
local volume = k.core.v1.volume;
local volumeMount = k.core.v1.volumeMount;

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'k8s/pocket-id',
  },
  spec: {
    namespace: 'pocket-id',
    resourceDefaults: {},
    expectVersions: {},
    contextNames: ['admin@asgard'],
  },
  data: {
    namespace: k.core.v1.namespace.new($.spec.namespace),

    // --- Storage ---

    dataPvc:
      pvc.new('pocket-id-data')
      + pvc.spec.withAccessModes(['ReadWriteOnce'])
      + pvc.spec.withStorageClassName('yggdrasil-iscsi-retain')
      + pvc.spec.resources.withRequests({ storage: '1Gi' }),

    // --- Secrets ---

    secrets:
      es.new('pocket-id-secrets')
      + es.withSecret('ENCRYPTION_KEY', 'pocket-id-encryption-key/encryption-key')
      + es.withSecret('DB_CONNECTION_STRING', 'pocket-id-db/connection-string'),

    // --- Config ---

    config: k.core.v1.configMap.new('pocket-id', {
      APP_URL: 'https://pocket-id.asgard.sykloid.org',
      ANALYTICS_DISABLED: 'true',
      GEOLITE_DB_PATH: 'data/GeoLite2-City.mmdb',
      GEOLITE_DB_URL: 'https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City&license_key=%s&suffix=tar.gz',
      HOST: '0.0.0.0',
      LOCAL_IPV6_RANGES: '',
      METRICS_ENABLED: 'false',
      PORT: '1411',
      TRACING_ENABLED: 'false',
      TRUST_PROXY: 'true',
      TZ: 'Etc/UTC',
      UI_CONFIG_DISABLED: 'false',
      UPDATE_CHECK_DISABLED: 'true',
      UPLOAD_PATH: 'data/uploads',
    }),

    // --- Pocket ID ---

    deployment: deploy.new('pocket-id', containers=[
      container.new('pocket-id', 'ghcr.io/pocket-id/pocket-id:v2.4.0')
      + container.withPorts([containerPort.newNamed(1411, 'http')])
      + container.withEnvFrom([
        { configMapRef: { name: 'pocket-id' } },
        { secretRef: { name: 'pocket-id-secrets' } },
      ])
      + container.withVolumeMounts([
        volumeMount.new('data', '/app/data'),
      ]),
    ])
    + deploy.spec.strategy.withType('Recreate')
    + deploy.spec.template.spec.withVolumes([
      volume.fromPersistentVolumeClaim('data', 'pocket-id-data'),
    ]),

    service: service.new('pocket-id', { name: 'pocket-id' }, [
      servicePort.new(80, 1411) + servicePort.withName('http'),
    ]),

    httpRoute: httpRoute.new('pocket-id-route', 'pocket-id.asgard.sykloid.org', 'pocket-id', 80),
  },
}
