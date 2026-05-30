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
        image: 'factory.talos.dev/metal-installer/c9078f9419961640c712a8bf2bb9174933dfcf1da383fd8ea2b7dc21493f8bac:v1.11.5',
        disk: installDisk,
      },
      sysctls: {
        'user.max_user_namespaces': '11255',
      },
      kubelet: {
        extraConfig: {
          featureGates: {
            UserNamespacesSupport: true,
            UserNamespacesPodSecurityStandards: true,
          },
        },
      },
    },
    cluster: {
      allowSchedulingOnControlPlanes: true,
      apiServer: {
        extraArgs: {
          'feature-gates': 'UserNamespacesSupport=true,UserNamespacesPodSecurityStandards=true',
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
}
