local k = import '1.33/main.libsonnet';

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'k8s/monitoring',
  },
  spec: {
    namespace: 'monitoring',
    resourceDefaults: {},
    expectVersions: {},
    contextNames: ['admin@asgard'],
  },
  data: {
    namespace: k.core.v1.namespace.new($.spec.namespace),

    vmSingle: {
      apiVersion: 'operator.victoriametrics.com/v1beta1',
      kind: 'VMSingle',
      metadata: {
        name: 'asgard',
        namespace: $.spec.namespace,
      },
      spec: {
        retentionPeriod: '1',
        removePvcAfterDelete: false,
        storage: {
          storageClassName: 'yggdrasil-retain',
          resources: {
            requests: {
              storage: '10Gi',
            },
          },
        },
        resources: {
          requests: {
            memory: '512Mi',
            cpu: '250m',
          },
          limits: {
            memory: '1Gi',
            cpu: '500m',
          },
        },
      },
    },

    vmAgent: {
      apiVersion: 'operator.victoriametrics.com/v1beta1',
      kind: 'VMAgent',
      metadata: {
        name: 'asgard',
        namespace: $.spec.namespace,
      },
      spec: {
        selectAllByDefault: true,
        remoteWrite: [
          {
            url: 'http://vmsingle-asgard:8428/api/v1/write',
          },
        ],
        resources: {
          requests: {
            memory: '256Mi',
            cpu: '100m',
          },
          limits: {
            memory: '512Mi',
            cpu: '250m',
          },
        },
      },
    },

    nodeExporterScrape: {
      apiVersion: 'operator.victoriametrics.com/v1beta1',
      kind: 'VMNodeScrape',
      metadata: {
        name: 'node-exporter',
        namespace: $.spec.namespace,
      },
      spec: {
        port: '9100',
        path: '/metrics',
        interval: '30s',
        relabelConfigs: [
          {
            replacement: 'node-exporter',
            targetLabel: 'job',
          },
          {
            sourceLabels: ['__meta_kubernetes_node_name'],
            targetLabel: 'instance',
          },
          {
            sourceLabels: ['__meta_kubernetes_node_name'],
            targetLabel: 'node',
          },
        ],
      },
    },
  },
}
