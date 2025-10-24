#!/usr/bin/env nu

let ENV_DIR = $"environments/($env.ARGOCD_ENV_TK_ENV)" | path expand

tk show --dangerous-allow-redirect $ENV_DIR