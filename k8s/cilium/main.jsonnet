local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'k8s/cilium',
  },
  spec: {
    namespace: 'kube-system',
    resourceDefaults: {},
    expectVersions: {},
    contextNames: ['admin@asgard'],
  },
  data: {
    cilium: helm.template(
      'cilium', 'charts/cilium', {
        namespace: $.spec.namespace,
        values: {
          routingMode: 'native',
          kubeProxyReplacement: true,
          'socketLB.hostNamespaceOnly': true,
          hubble: {
            enabled: true,
            ui: {
              enabled: true,
            },
            relay: {
              enabled: true,
            },
          },
          gatewayAPI: {
            enabled: true,
            enableAlpn: true,
            enableAppProtocol: true,
          },
          securityContext: {
            capabilities: {
              ciliumAgent: [
                'CHOWN',
                'KILL',
                'NET_ADMIN',
                'NET_RAW',
                'IPC_LOCK',
                'SYS_ADMIN',
                'SYS_RESOURCE',
                'DAC_OVERRIDE',
                'FOWNER',
                'SETGID',
                'SETUID',
              ],
              cleanCiliumState: [
                'NET_ADMIN',
                'SYS_ADMIN',
                'SYS_RESOURCE',
              ],
            },
          },
          cgroup: {
            automount: {
              enabled: false,
            },
            hostRoot: '/sys/fs/cgroup',
          },
          ipam: {
            mode: 'kubernetes',
          },
          k8sServiceHost: 'localhost',
          k8sServicePort: 7445,
        },
      }
    ),
  },
}
