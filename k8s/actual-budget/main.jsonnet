local k = import '1.33/main.libsonnet';
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
    name: 'k8s/actual-budget',
  },
  spec: {
    namespace: 'actual-budget',
    resourceDefaults: {},
    expectVersions: {},
    contextNames: ['admin@asgard'],
  },
  data: {
    namespace: k.core.v1.namespace.new($.spec.namespace),

    // --- Storage ---

    dataPvc:
      pvc.new('actual-budget-data')
      + pvc.spec.withAccessModes(['ReadWriteOnce'])
      + pvc.spec.withStorageClassName('yggdrasil-iscsi-retain')
      + pvc.spec.resources.withRequests({ storage: '5Gi' }),

    // --- Actual Budget ---

    deployment: deploy.new('actual-budget', containers=[
      container.new('actual-budget', 'ghcr.io/actualbudget/actual-server:25.2.1')
      + container.withPorts([containerPort.new(5006)])
      + container.withVolumeMounts([
        volumeMount.new('data', '/data'),
      ]),
    ])
    + deploy.spec.strategy.withType('Recreate')
    + deploy.spec.template.spec.withVolumes([
      volume.fromPersistentVolumeClaim('data', 'actual-budget-data'),
    ]),

    service: service.new('actual-budget', { name: 'actual-budget' }, [
      servicePort.new(5006, 5006),
    ]),

    // --- HTTPRoute ---

    httpRoute: {
      apiVersion: 'gateway.networking.k8s.io/v1',
      kind: 'HTTPRoute',
      metadata: {
        name: 'actual-budget-route',
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
        hostnames: ['actual-budget.asgard.sykloid.org'],
        rules: [
          {
            matches: [
              { path: { type: 'PathPrefix', value: '/' } },
            ],
            backendRefs: [
              {
                group: '',
                kind: 'Service',
                name: 'actual-budget',
                port: 5006,
                weight: 1,
              },
            ],
          },
        ],
      },
    },
  },
}
