// Machine config pieces shared by every Talos node in the cluster.
{
  machine: {
    sysctls: {
      'user.max_user_namespaces': '11255',
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
