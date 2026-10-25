local k = import '1.33/main.libsonnet';
local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

// Dynamic Resource Allocation driver for NVIDIA GPUs: publishes GPUs as
// ResourceSlices (DeviceClass gpu.nvidia.com) and injects them into claiming
// pods via CDI. The driver and container toolkit are baked into the node image
// by Talos system extensions (talos/worker-gpu/schematic.yml), so nothing is
// installed on the host.
{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'k8s/dra-driver-nvidia-gpu',
  },
  spec: {
    namespace: 'dra-driver-nvidia-gpu',
    resourceDefaults: {},
    expectVersions: {},
    contextNames: ['admin@asgard'],
  },
  data: {
    // The kubelet plugin is privileged and mounts kubelet plugin dirs and /dev.
    namespace: k.core.v1.namespace.new($.spec.namespace)
               + k.core.v1.namespace.metadata.withLabels({
                 'pod-security.kubernetes.io/enforce': 'privileged',
               }),

    draDriver: helm.template('dra-driver-nvidia-gpu', 'charts/dra-driver-nvidia-gpu', {
      namespace: $.spec.namespace,
      values: {
        // Talos's NVIDIA extensions install nvidia-smi under /usr/local/bin and
        // libnvidia-ml under /usr/local/lib64; the plugin only searches fixed
        // bin/ and lib64/ paths under the driver root, so "/" finds nothing.
        // There is no /usr/local/dev, so /dev/nvidia* still resolve from "/".
        nvidiaDriverRoot: '/usr/local',
        gpuResourcesEnabledOverride: true,
        // The chart auto-detects this from cluster capabilities, which `helm
        // template` (Tanka) can't see, so it falls back to v1beta2. Kubernetes
        // 1.36 serves only resource.k8s.io/v1.
        resourceApiVersion: 'resource.k8s.io/v1',
        resources: {
          gpus: { enabled: true },
          // Multi-node NVLink (GB200/GB300 NVL72) only.
          computeDomains: { enabled: false },
        },
        // The chart's default kubelet-plugin affinity already accepts
        // nvidia.com/gpu.present=true, set on GPU nodes by their Talos config
        // (no NFD in this cluster), and it tolerates the nvidia.com/gpu taint.
      },
    }),
  },
}
