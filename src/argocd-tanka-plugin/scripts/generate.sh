#!/usr/bin/env bash
set -euo pipefail

tk show --dangerous-allow-redirect "${ARGOCD_ENV_TK_ENV}"
