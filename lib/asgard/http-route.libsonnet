{
  new: function(name, hostname, serviceName, port) {
    apiVersion: 'gateway.networking.k8s.io/v1',
    kind: 'HTTPRoute',
    metadata: {
      name: name,
    },
    spec: {
      parentRefs: [
        {
          group: 'gateway.networking.k8s.io',
          kind: 'Gateway',
          name: 'tailscale-secure-gateway',
          namespace: 'tailscale',
        },
      ],
      hostnames: [hostname],
      rules: [
        {
          matches: [
            { path: { type: 'PathPrefix', value: '/' } },
          ],
          backendRefs: [
            {
              group: '',
              kind: 'Service',
              name: serviceName,
              port: port,
              weight: 1,
            },
          ],
        },
      ],
    },
  },
}
