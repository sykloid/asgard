#!/usr/bin/env bash
set -euo pipefail

jb install

if [ -f "${ARGOCD_ENV_TK_ENV}/chartfile.yaml" ]; then
  cd "${ARGOCD_ENV_TK_ENV}"
  export HOME="/tmp/helm"
  tk tool charts vendor
fi
