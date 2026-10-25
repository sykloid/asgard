local common = import 'asgard/talos.libsonnet';

// NVIDIA GB10 (Grace Blackwell, arm64) GPU workers. The schematic carries the
// proprietary driver (the open modules don't boot on GB10) and arm64.nobti.
function(hostname, installDisk) {
  machineConfig: {
    apiVersion: 'v1alpha1',
    kind: 'MachineConfig',
    metadata: {
      name: 'asgard-worker-gpu',
    },
    machine: common.machine {
      network: {
        hostname: hostname,
        interfaces: [
          {
            // Onboard 10GbE (Realtek RTL8127); the ConnectX-7 ports stay unconfigured.
            deviceSelector: {
              driver: 'r8169',
            },
            dhcp: true,
          },
        ],
      },
      install: {
        image: 'factory.talos.dev/metal-installer/2c3e2f033ecf0565e7700c66011e47fc3f0c68a83b6b76afd5fb8d106e8fb052:v1.14.2',
        disk: installDisk,
      },
      kernel: {
        modules: [
          { name: 'nvidia' },
          { name: 'nvidia_uvm' },
          { name: 'nvidia_drm' },
          { name: 'nvidia_modeset' },
        ],
      },
      // Only applied when the node first registers; later changes need kubectl taint.
      nodeTaints: {
        'nvidia.com/gpu': 'present:NoSchedule',
      },
      kubelet: {
        // Lets hostPath pods see user volumes mounted under /var/mnt after kubelet starts.
        extraMounts: [
          {
            destination: '/var/mnt',
            type: 'bind',
            source: '/var/mnt',
            options: ['bind', 'rshared', 'rw'],
          },
        ],
      },
    },
    cluster: common.cluster,
  },
  pocketIDHost: common.pocketIDHost,
  kmsgLog: common.kmsgLog,
  // Both sizes are fixed when the partitions are first created; changing them
  // later means wiping EPHEMERAL / the volume.
  ephemeralVolume: {
    apiVersion: 'v1alpha1',
    kind: 'VolumeConfig',
    metadata: {
      name: 'ephemeral',
    },
    name: 'EPHEMERAL',
    provisioning: {
      maxSize: '500GiB',
    },
  },
  // Bulk data (e.g. model weights), mounted at /var/mnt/data; takes the rest of the system disk.
  dataVolume: {
    apiVersion: 'v1alpha1',
    kind: 'UserVolumeConfig',
    metadata: {
      name: 'data',
    },
    name: 'data',
    provisioning: {
      diskSelector: {
        match: 'system_disk',
      },
      minSize: '1TiB',
      grow: true,
    },
    filesystem: {
      type: 'xfs',
    },
  },
}
