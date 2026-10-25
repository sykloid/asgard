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

// Level-name -> OTLP severity mapping shared by the stanza severity parsers.
local severityMapping = {
  trace: 'trace',
  debug: 'debug',
  info: ['info', 'notice', 'information'],
  warn: ['warn', 'warning'],
  'error': ['error', 'err'],
  fatal: ['fatal', 'critical', 'panic', 'crit'],
};

// Canonicalize severity_text from the OTLP severity_number that the
// per-format severity parsing sets, so VictoriaLogs stores a uniform
// `severity` (trace/debug/info/warn/error/critical) regardless of the
// source log format (json/logfmt/klog/bracketed) or original casing.
local severityTransform = {
  error_mode: 'ignore',
  log_statements: [
    {
      context: 'log',
      statements: [
        'set(severity_text, "trace") where severity_number >= 1 and severity_number <= 4',
        'set(severity_text, "debug") where severity_number >= 5 and severity_number <= 8',
        'set(severity_text, "info") where severity_number >= 9 and severity_number <= 12',
        'set(severity_text, "warn") where severity_number >= 13 and severity_number <= 16',
        'set(severity_text, "error") where severity_number >= 17 and severity_number <= 20',
        'set(severity_text, "critical") where severity_number >= 21 and severity_number <= 24',
      ],
    },
  ],
};

// Talos ships machined/kubelet/etcd/etc. service logs and the kernel log as
// JSON lines over TCP (machine.logging + KmsgLogConfig in
// lib/asgard/talos.libsonnet) to these ports on otel-logs-agent.
local talosServiceLogsPort = 5170;
local talosKernelLogsPort = 5171;

// Parse one Talos JSON line: fields to attributes, talos-time/talos-level to
// timestamp/severity, msg to the body.
local talosOperators = [
  {
    type: 'json_parser',
    parse_from: 'body',
    timestamp: {
      parse_from: 'attributes["talos-time"]',
      layout_type: 'gotime',
      layout: '2006-01-02T15:04:05.999999999Z07:00',
    },
    severity: {
      parse_from: 'attributes["talos-level"]',
      mapping: severityMapping,
    },
  },
  { type: 'move', 'if': 'attributes.msg != nil', from: 'attributes.msg', to: 'body' },
  { type: 'remove', field: 'attributes["talos-time"]' },
  { type: 'remove', field: 'attributes["talos-level"]' },
];

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
        // Host network so Talos can reach the talos-* receivers on 127.0.0.1.
        hostNetwork: true,
        dnsPolicy: 'ClusterFirstWithHostNet',
        // Every node, whatever its taints, so node problems are visible.
        tolerations: [{ operator: 'Exists' }],
        // Nothing serves the chart's default ports (those receivers are removed
        // below); don't reserve them on the host.
        ports: {
          otlp: { enabled: false },
          'otlp-http': { enabled: false },
          'jaeger-compact': { enabled: false },
          'jaeger-thrift': { enabled: false },
          'jaeger-grpc': { enabled: false },
          zipkin: { enabled: false },
        },
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
          receivers: {
            otlp: null,
            jaeger: null,
            zipkin: null,
            prometheus: null,
            'tcplog/talos-services': {
              listen_address: '127.0.0.1:%d' % talosServiceLogsPort,
              operators: talosOperators + [
                // On connect Talos also replays the kernel buffer here, as
                // pre-formatted text stamped with the send time; the kernel
                // receiver below already carries it with real timestamps.
                { type: 'filter', expr: 'attributes["talos-service"] == "kernel"' },
              ],
            },
            'tcplog/talos-kernel': {
              listen_address: '127.0.0.1:%d' % talosKernelLogsPort,
              operators: talosOperators + [
                { type: 'add', field: 'attributes["talos-service"]', value: 'kernel' },
              ],
            },
            // Extend the logsCollection preset's filelog operators: keep its
            // container parser, then parse JSON-formatted log bodies into
            // structured fields and set the record severity from the level.
            // Plaintext lines fail the `if` guard and pass through untouched.
            filelog: {
              operators: [
                { id: 'container-parser', type: 'container', max_log_size: 102400 },
                {
                  // Flatten the JSON body into attributes (-> VictoriaLogs
                  // fields) and derive OTLP severity from the level, so
                  // VictoriaLogs stores a real `severity` instead of
                  // "Unspecified" and Grafana can stack the level histogram.
                  type: 'json_parser',
                  'if': 'body matches "^{.*}$"',
                  parse_from: 'body',
                  on_error: 'send_quiet',
                  severity: {
                    parse_from: 'attributes.level',
                    mapping: {
                      trace: 'trace',
                      debug: 'debug',
                      info: ['info', 'notice', 'information'],
                      warn: ['warn', 'warning'],
                      'error': ['error', 'err'],
                      fatal: ['fatal', 'critical', 'panic', 'crit'],
                    },
                  },
                },
                // Use the structured message as the log body (_msg) instead of
                // the raw JSON string. Apps that use `message` instead of `msg`
                // would need an extra move; plaintext logs have neither and are
                // left as-is.
                { type: 'move', 'if': 'attributes.msg != nil', from: 'attributes.msg', to: 'body' },
                // Level is now encoded in severity; drop the redundant field so
                // Grafana does not render a duplicate "level" column
                // (victorialogs-datasource#319).
                { type: 'remove', 'if': 'attributes.level != nil', field: 'attributes.level' },
                // logfmt branch (severity-only): non-JSON `key=value` logs that
                // carry a level= (e.g. argo-cd's gRPC logger) reach here with
                // the raw line still in body. Extract just the level into a
                // scratch attribute, set severity from it, then drop the scratch
                // -- body/_msg and other fields are left untouched (no flatten).
                {
                  // NB: `if` is an expr-lang expression, so `\s` would be an
                  // invalid string escape here -- use a literal space (logfmt
                  // fields are space-separated). The `regex` field below goes
                  // straight to the regex engine, where `\w` is fine.
                  type: 'regex_parser',
                  'if': 'body matches "(^| )level="',
                  regex: 'level="?(?P<level>\\w+)',
                  parse_from: 'body',
                  parse_to: 'attributes.lvltmp',
                  on_error: 'send_quiet',
                  severity: {
                    parse_from: 'attributes.lvltmp.level',
                    mapping: {
                      trace: 'trace',
                      debug: 'debug',
                      info: ['info', 'notice', 'information'],
                      warn: ['warn', 'warning'],
                      'error': ['error', 'err'],
                      fatal: ['fatal', 'critical', 'panic', 'crit'],
                    },
                  },
                },
                { type: 'remove', 'if': 'attributes.lvltmp != nil', field: 'attributes.lvltmp' },
                // klog/glog branch (severity-only): Kubernetes components and CSI
                // sidecars log "I0622 00:07:20.304314 1 file.go:1] msg" -- the
                // level is the leading char I/W/E/F.
                {
                  type: 'regex_parser',
                  'if': 'body matches "^[IWEF][0-9]{4} "',
                  regex: '^(?P<level>[IWEF])',
                  parse_from: 'body',
                  parse_to: 'attributes.lvltmp',
                  on_error: 'send_quiet',
                  severity: {
                    parse_from: 'attributes.lvltmp.level',
                    mapping: { info: 'I', warn: 'W', 'error': 'E', fatal: 'F' },
                  },
                },
                { type: 'remove', 'if': 'attributes.lvltmp != nil', field: 'attributes.lvltmp' },
                // bracketed-level branch (severity-only): e.g. synology csi-plugin
                // logs "<ts> [INFO] [file:line] msg" -- level in the first
                // [BRACKET]. The `if` guard avoids `\[` (invalid expr-lang escape)
                // via char classes; the regex field uses normal escaping.
                {
                  type: 'regex_parser',
                  'if': 'body matches " [[][A-Z]+[]]"',
                  regex: '\\[(?P<level>[A-Z]+)\\]',
                  parse_from: 'body',
                  parse_to: 'attributes.lvltmp',
                  on_error: 'send_quiet',
                  severity: {
                    parse_from: 'attributes.lvltmp.level',
                    mapping: {
                      info: ['INFO', 'INFORMATION', 'NOTICE'],
                      warn: ['WARN', 'WARNING'],
                      'error': ['ERROR', 'ERR'],
                      debug: 'DEBUG',
                      trace: 'TRACE',
                      fatal: ['FATAL', 'CRITICAL', 'CRIT', 'PANIC'],
                    },
                  },
                },
                { type: 'remove', 'if': 'attributes.lvltmp != nil', field: 'attributes.lvltmp' },
                // Python logging branch (severity-only): home-assistant/paperless
                // log "<date> HH:MM:SS.mmm LEVEL (thread) [logger] msg", often
                // wrapped in ANSI color codes. Capture the level word between the
                // timestamp and the " (thread)". The match is unanchored, so the
                // leading ANSI escape is ignored; body is left intact.
                {
                  type: 'regex_parser',
                  'if': 'body matches "[0-9]{2}:[0-9]{2}:[0-9]{2}[.,][0-9]+ [A-Z]+ [(]"',
                  regex: '[0-9]{2}:[0-9]{2}:[0-9]{2}[.,][0-9]+ (?P<level>[A-Z]+) [(]',
                  parse_from: 'body',
                  parse_to: 'attributes.lvltmp',
                  on_error: 'send_quiet',
                  severity: {
                    parse_from: 'attributes.lvltmp.level',
                    mapping: {
                      debug: 'DEBUG',
                      info: ['INFO', 'INFORMATION'],
                      warn: ['WARNING', 'WARN'],
                      'error': ['ERROR', 'ERR'],
                      fatal: ['CRITICAL', 'FATAL'],
                    },
                  },
                },
                { type: 'remove', 'if': 'attributes.lvltmp != nil', field: 'attributes.lvltmp' },
              ],
            },
          },
          processors: {
            memory_limiter: null,
            transform: severityTransform,
            // Promote talos-service to a resource attribute so each Talos
            // service is its own VictoriaLogs stream.
            groupbyattrs: { keys: ['talos-service'] },
            'resource/node': {
              attributes: [
                // OTEL_K8S_NODE_NAME is injected by the chart from spec.nodeName.
                { key: 'k8s.node.name', value: '${env:OTEL_K8S_NODE_NAME}', action: 'upsert' },
              ],
            },
          },
          exporters: vlogsExporter { debug: null },
          service: {
            pipelines: {
              metrics: null,
              traces: null,
              logs: {
                receivers: ['filelog'],
                processors: ['k8sattributes', 'transform', 'batch'],
                exporters: ['otlphttp/vlogs'],
              },
              // Talos host logs carry no pod, so they skip k8sattributes.
              'logs/talos': {
                receivers: ['tcplog/talos-services', 'tcplog/talos-kernel'],
                processors: ['transform', 'groupbyattrs', 'resource/node', 'batch'],
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
          processors: {
            memory_limiter: null,
            // k8sobjects emits each event as a structured body ({type, object:{...}})
            // with no log message, so VictoriaLogs shows a "missing _msg field"
            // placeholder. Lift the event object's fields up to attributes (so
            // they survive as queryable fields) and use the event note (falling
            // back to reason) as the log message body.
            transform: {
              error_mode: 'ignore',
              log_statements: [
                {
                  context: 'log',
                  statements: [
                    'merge_maps(attributes, body["object"], "upsert") where body["object"] != nil',
                    // Derive severity from the k8s event type. Set severity_text
                    // directly to the canonical value (the events collector has no
                    // severity_number canonicalize transform like the logs one).
                    'set(severity_text, "warn") where attributes["type"] == "Warning"',
                    'set(severity_text, "info") where attributes["type"] == "Normal"',
                    'set(body, attributes["note"]) where attributes["note"] != nil',
                    'set(body, attributes["reason"]) where attributes["note"] == nil and attributes["reason"] != nil',
                  ],
                },
              ],
            },
          },
          exporters: vlogsExporter { debug: null },
          service: {
            pipelines: {
              metrics: null,
              traces: null,
              logs: {
                receivers: ['k8sobjects'],
                processors: ['transform', 'batch'],
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
