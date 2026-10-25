local argoCD = import 'asgard/argo-cd.libsonnet';

{
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'k8s/asgard',
  },
  spec: {
    namespace: 'argo-cd',
    resourceDefaults: {},
    expectVersions: {},
    contextNames: [
      'admin@asgard',
    ],
  },
  data: {
    argoCD: argoCD.application.new('argo-cd'),
    cilium: argoCD.application.new('cilium', namespace='kube-system'),
    envoyGateway: argoCD.application.new('envoy-gateway', namespace='envoy-gateway-system'),
    nfsProvisioner: argoCD.application.new('nfs-subdir-external-provisioner'),
    externalSecrets: argoCD.application.new('external-secrets'),
    certManager: argoCD.application.new('cert-manager'),
    tailscale: argoCD.application.new('tailscale'),
    synologyCSI: argoCD.application.new('synology-csi'),
    pihole: argoCD.application.new('pihole'),
    externalDNS: argoCD.application.new('external-dns'),
    nodeExporter: argoCD.application.new('node-exporter'),
    monitoring: argoCD.application.new('monitoring'),
    otelCollector: argoCD.application.new('otel-collector'),
    paperlessNgx: argoCD.application.new('paperless-ngx'),
    snmpExporter: argoCD.application.new('snmp-exporter'),
    actualBudget: argoCD.application.new('actual-budget'),
    grafana: argoCD.application.new('grafana'),
    argoWorkflows: argoCD.application.new('argo-workflows'),
    pocketID: argoCD.application.new('pocket-id') +
              argoCD.application.withIgnoreDifferences([
                {
                  group: 'apps',
                  kind: 'StatefulSet',
                  name: 'pocket-id',
                  jsonPointers: [
                    '/spec/updateStrategy/rollingUpdate/maxUnavailable',
                  ],
                },
              ]),
  },
}
