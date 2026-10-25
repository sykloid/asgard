// Machine config pieces shared by every Talos node in the cluster.
{
  machine: {
    sysctls: {
      'user.max_user_namespaces': '11255',
    },
    // Ship service logs (machined, kubelet, etcd, ...) to the node-local
    // otel-logs-agent (k8s/otel-collector), which forwards to VictoriaLogs.
    logging: {
      destinations: [
        { endpoint: 'tcp://127.0.0.1:5170/', format: 'json_lines' },
      ],
    },
  },
  cluster: {
    discovery: {
      enabled: false,
    },
    network: {
      cni: {
        name: 'none',
      },
    },
    proxy: {
      disabled: true,
    },
  },
  // Kernel log to the same collector, on its own port.
  kmsgLog: {
    apiVersion: 'v1alpha1',
    kind: 'KmsgLogConfig',
    metadata: {
      name: 'otel-logs',
    },
    name: 'otel-logs',
    url: 'tcp://127.0.0.1:5171/',
  },
  // In-cluster OIDC clients need to resolve Pocket ID, whose record only exists
  // in pihole. Points at the tailscale-secure-gateway address that external-dns
  // publishes; cilium routes it in-cluster.
  pocketIDHost: {
    apiVersion: 'v1alpha1',
    kind: 'StaticHostConfig',
    metadata: {
      name: 'pocket-id',
    },
    name: '100.125.239.39',
    hostnames: [
      'pocket-id.asgard.sykloid.org',
    ],
  },
}
