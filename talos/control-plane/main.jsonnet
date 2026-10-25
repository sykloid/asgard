local common = import 'asgard/talos.libsonnet';

function(hostname, installDisk) {
  machineConfig: {
    apiVersion: 'v1alpha1',
    kind: 'MachineConfig',
    metadata: {
      name: 'asgard-control-plane',
    },
    machine: common.machine {
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
    },
    cluster: common.cluster {
      allowSchedulingOnControlPlanes: true,
    },
  },
  pocketIDHost: common.pocketIDHost,
  kmsgLog: common.kmsgLog,
}
