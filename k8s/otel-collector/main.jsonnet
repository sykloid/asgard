local k = import '1.33/main.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

// VictoriaLogs OTLP ingestion endpoint. vlSingle lives in the monitoring
// namespace; we reach it cross-namespace via its cluster DNS name.
local vlogsEndpoint = 'http://vlsingle-asgard.monitoring.svc:9428/insert/opentelemetry/v1/logs';

// otlphttp exporter pointing at VictoriaLogs. Plain HTTP inside the cluster, so
// TLS is disabled. VictoriaLogs turns OTLP resource attributes (e.g. the
// k8s.* attributes added by the k8sattributes preset) into log stream fields.
local vlogsExporter = {
  'otlphttp/vlogs': {
    logs_endpoint: vlogsEndpoint,
    tls: { insecure: true },
  },
};

// The contrib distribution is required: the filelog and k8sobjects receivers
// are not in the core collector image.
local contribImage = { repository: 'otel/opentelemetry-collector-contrib' };

// Two-tier collector layout per the OpenTelemetry Kubernetes docs:
//   - DaemonSet (agent) for node-local data  -> filelog (container logs)
//   - single Deployment replica for cluster-wide data -> k8sobjects (events)
// Cluster-wide receivers must run as exactly one replica or they emit
// duplicate data.
{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'k8s/otel-collector',
  },
  spec: {
    namespace: 'otel-collector',
    resourceDefaults: {},
    expectVersions: {},
    contextNames: ['admin@asgard'],
  },
  data: {
    // The logs DaemonSet mounts host paths (/var/log/pods) to read container
    // logs, which requires the privileged Pod Security Standard.
    namespace: k.core.v1.namespace.new($.spec.namespace)
               + k.core.v1.namespace.metadata.withLabels({
                 'pod-security.kubernetes.io/enforce': 'privileged',
               }),

    // Per-node DaemonSet: tails container stdout/stderr from
    // /var/log/containers (logsCollection preset adds the filelog receiver and
    // host mounts) and ships to VictoriaLogs over OTLP.
    logs: helm.template('otel-logs', 'charts/opentelemetry-collector', {
      namespace: $.spec.namespace,
      values: {
        fullnameOverride: 'otel-logs',
        mode: 'daemonset',
        image: contribImage,
        presets: {
          logsCollection: { enabled: true, includeCollectorLogs: false },
          // Enrich each record with k8s.namespace.name / k8s.pod.name /
          // k8s.container.name etc., which become VictoriaLogs stream fields.
          kubernetesAttributes: { enabled: true },
        },
        config: {
          // Drop the chart's default metrics/traces pipelines and their unused
          // components (null tells the chart to remove the key) so this
          // collector runs only the filelog -> VictoriaLogs logs pipeline.
          receivers: { otlp: null, jaeger: null, zipkin: null, prometheus: null },
          processors: { memory_limiter: null },
          exporters: vlogsExporter { debug: null },
          service: {
            pipelines: {
              metrics: null,
              traces: null,
              logs: {
                receivers: ['filelog'],
                processors: ['k8sattributes', 'batch'],
                exporters: ['otlphttp/vlogs'],
              },
            },
          },
        },
        resources: {
          limits: { cpu: '250m', memory: '256Mi' },
        },
      },
    }),

    // Single Deployment: watches the Kubernetes Events API (kubernetesEvents
    // preset adds the k8sobjects receiver + cluster RBAC) and ships events as
    // logs. One replica so events are not duplicated.
    events: helm.template('otel-events', 'charts/opentelemetry-collector', {
      namespace: $.spec.namespace,
      values: {
        fullnameOverride: 'otel-events',
        mode: 'deployment',
        replicaCount: 1,
        image: contribImage,
        presets: {
          kubernetesEvents: { enabled: true },
        },
        config: {
          // Drop the chart's default metrics/traces pipelines and their unused
          // components (null tells the chart to remove the key) so this
          // collector runs only the k8sobjects -> VictoriaLogs logs pipeline.
          receivers: { otlp: null, jaeger: null, zipkin: null, prometheus: null },
          processors: { memory_limiter: null },
          exporters: vlogsExporter { debug: null },
          service: {
            pipelines: {
              metrics: null,
              traces: null,
              logs: {
                receivers: ['k8sobjects'],
                processors: ['batch'],
                exporters: ['otlphttp/vlogs'],
              },
            },
          },
        },
        resources: {
          limits: { cpu: '100m', memory: '128Mi' },
        },
      },
    }),
  },
}
