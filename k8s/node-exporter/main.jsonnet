local k = import '1.33/main.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'k8s/node-exporter',
  },
  spec: {
    namespace: 'node-exporter',
    resourceDefaults: {},
    expectVersions: {},
    contextNames: ['admin@asgard'],
  },
  data: {
    namespace: k.core.v1.namespace.new($.spec.namespace) +
               k.core.v1.namespace.metadata.withLabels({
                 'pod-security.kubernetes.io/enforce': 'privileged',
               }),

    nodeExporter: helm.template('node-exporter', 'charts/prometheus-node-exporter', {
      namespace: $.spec.namespace,
      values: {
        fullnameOverride: 'node-exporter',
        hostNetwork: true,
        hostPID: true,
        hostRootFsMountPropagation: 'HostToContainer',
      },
    }),
  },
}
