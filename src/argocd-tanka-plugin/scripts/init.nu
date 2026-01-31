#!/usr/bin/env nu

jb install

let ENV_DIR = $"environments/($env.ARGOCD_ENV_TK_ENV)" | path expand

if ($"($ENV_DIR)/chartfile.yaml" | path exists) {
  cd $ENV_DIR
  $env.HOME = "/tmp/helm"
  tk tool charts vendor
}
