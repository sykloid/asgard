function(hostname, installDisk) {
  machineConfig: {
    apiVersion: 'v1alpha1',
    kind: 'MachineConfig',
    metadata: {
      name: 'asgard-control-plane',
    },
    machine: {
      network: {
        hostname: hostname,
        interfaces: [
          {
            interface: 'enp0s31f6',
            dhcp: true,
            vip: {
              ip: '192.168.1.16',
            },
          },
        ],
      },
      install: {
        image: 'factory.talos.dev/metal-installer/c9078f9419961640c712a8bf2bb9174933dfcf1da383fd8ea2b7dc21493f8bac:v1.14.2',
        disk: installDisk,
      },
      sysctls: {
        'user.max_user_namespaces': '11255',
      },
      kubelet: {
        extraConfig: {
          featureGates: {
            UserNamespacesSupport: true,
          },
        },
      },
    },
    cluster: {
      allowSchedulingOnControlPlanes: true,
      apiServer: {
        extraArgs: {
          'feature-gates': 'UserNamespacesSupport=true',
        },
      },
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
