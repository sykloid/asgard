local k = import '1.33/main.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'environments/pocket-id',
  },
  spec: {
    namespace: 'pocket-id',
    resourceDefaults: {},
    expectVersions: {},
    contextNames: ['admin@asgard'],
  },
  data: {
    namespace: k.core.v1.namespace.new('pocket-id'),
    pocketID: helm.template('pocket-id', 'charts/pocket-id', {
      namespace: $.spec.namespace,
      values: {
        host: 'pocket-id.asgard.sykloid.org',
        persistence: {
          data: {
            storageClass: 'yggdrasil-iscsi-retain',
          },
        },
        config: {
          create: false,
          name: 'pocket-id',
        },
      },
    }),
    pocketIDConfig: k.core.v1.configMap.new('pocket-id', {
      ANALYTICS_DISABLED: 'false',
      APP_URL: 'https://pocket-id.asgard.sykloid.org',
      INTERNAL_APP_URL: 'http://pocket-id.pocket-id',
      DB_PROVIDER: 'sqlite',
      GEOLITE_DB_PATH: 'data/GeoLite2-City.mmdb',
      GEOLITE_DB_URL: 'https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City&license_key=%s&suffix=tar.gz',
      HOST: '0.0.0.0',
      KEYS_PATH: 'data/keys',
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
  },
}
