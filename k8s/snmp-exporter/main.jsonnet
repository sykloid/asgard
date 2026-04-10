local k = import '1.33/main.libsonnet';

local container = k.core.v1.container;
local containerPort = k.core.v1.containerPort;
local deploy = k.apps.v1.deployment;
local service = k.core.v1.service;
local servicePort = k.core.v1.servicePort;
local volume = k.core.v1.volume;
local volumeMount = k.core.v1.volumeMount;

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'k8s/snmp-exporter',
  },
  spec: {
    namespace: 'snmp-exporter',
    resourceDefaults: {},
    expectVersions: {},
    contextNames: ['admin@asgard'],
  },
  data: {
    namespace: k.core.v1.namespace.new($.spec.namespace),

    // --- Config (ExternalSecret with templated snmp.yml) ---

    config: {
      apiVersion: 'external-secrets.io/v1',
      kind: 'ExternalSecret',
      metadata: {
        name: 'snmp-exporter-config',
      },
      spec: {
        secretStoreRef: {
          kind: 'ClusterSecretStore',
          name: 'asgard-1password',
        },
        refreshInterval: '24h',
        target: {
          creationPolicy: 'Owner',
          deletionPolicy: 'Retain',
          template: {
            data: {
              'snmp.yml': importstr 'snmp.yml',
            },
          },
        },
        data: [
          {
            secretKey: 'username',
            remoteRef: {
              key: 'yggdrassil-snmp/username',
              conversionStrategy: 'Default',
              decodingStrategy: 'None',
              metadataPolicy: 'None',
            },
          },
          {
            secretKey: 'password',
            remoteRef: {
              key: 'yggdrassil-snmp/password',
              conversionStrategy: 'Default',
              decodingStrategy: 'None',
              metadataPolicy: 'None',
            },
          },
        ],
      },
    },

    // --- SNMP Exporter ---

    deployment: deploy.new('snmp-exporter', containers=[
      container.new('snmp-exporter', 'prom/snmp-exporter:v0.26.0')
      + container.withPorts([containerPort.new(9116)])
      + container.withArgs(['--config.file=/etc/snmp_exporter/snmp.yml'])
      + container.withVolumeMounts([
        volumeMount.new('config', '/etc/snmp_exporter'),
      ]),
    ])
    + deploy.spec.template.spec.withVolumes([
      volume.fromSecret('config', 'snmp-exporter-config'),
    ]),

    service: service.new('snmp-exporter', { name: 'snmp-exporter' }, [
      servicePort.new(9116, 9116) + servicePort.withName('http'),
    ]) + service.metadata.withLabels({ name: 'snmp-exporter' }),

    // --- Scrape Config ---

    vmServiceScrape: {
      apiVersion: 'operator.victoriametrics.com/v1beta1',
      kind: 'VMServiceScrape',
      metadata: {
        name: 'snmp-exporter',
      },
      spec: {
        selector: {
          matchLabels: {
            name: 'snmp-exporter',
          },
        },
        endpoints: [
          {
            port: 'http',
            path: '/snmp',
            params: {
              target: ['192.168.1.3'],
              module: ['synology'],
              auth: ['synology'],
            },
            interval: '60s',
            relabelConfigs: [
              {
                targetLabel: 'instance',
                replacement: 'yggdrasil',
              },
            ],
          },
        ],
      },
    },
  },
}
