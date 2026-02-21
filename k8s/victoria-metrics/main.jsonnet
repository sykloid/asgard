local k = import '1.33/main.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'k8s/victoria-metrics',
  },
  spec: {
    namespace: 'victoria-metrics',
    resourceDefaults: {},
    expectVersions: {},
    contextNames: ['admin@asgard'],
  },
  data: {
    namespace: k.core.v1.namespace.new($.spec.namespace) + k.core.v1.namespace.metadata.withLabels({
      'pod-security.kubernetes.io/enforce': 'privileged',
    }),
    vmOperator: helm.template('victoria-metrics-operator', 'charts/victoria-metrics-operator', {
      namespace: $.spec.namespace,
      values: {
        fullnameOverride: 'victoria-metrics-operator',
      },
    }),
  },
}
