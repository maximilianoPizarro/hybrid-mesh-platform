#!/usr/bin/env bash
# Day-2 bootstrap after RHDP hub+spokes sync (or when Argo apps are Unknown).
# Runs mesh/showroom/MCP fixes and strict HTTP 200 verification.
#
# Prerequisites:
#   - oc logged in to hub (export KUBECONFIG=/tmp/hub-kubeconfig)
#   - Optional spoke kubeconfigs at /tmp/east-kubeconfig, /tmp/west-kubeconfig
#   - ManagedClusters east/west Available (for domain auto-detect)
#
# Usage:
#   bash scripts/apply-post-install-day2.sh
#   SKIP_MESH=1 bash scripts/apply-post-install-day2.sh   # skip fleet mesh (already done)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "=============================================="
echo " Hybrid Mesh Platform — post-install day-2"
echo "=============================================="

if [[ "${SKIP_MESH:-}" != "1" ]]; then
  bash "$ROOT/scripts/apply-fleet-mesh.sh"
fi

bash "$ROOT/scripts/apply-workshop-showroom.sh"
bash "$ROOT/scripts/apply-mcp-gateway.sh"
bash "$ROOT/scripts/apply-istio-monitoring.sh"
bash "$ROOT/scripts/apply-workshop-kuadrant-apis.sh"
bash "$ROOT/scripts/sync-kuadrant-apiproduct-plans.sh"
bash "$ROOT/scripts/apply-hub-resource-relief.sh"
bash "$ROOT/scripts/apply-gitlab-bootstrap.sh" || true

if [[ -n "${ROX_ADMIN_PASSWORD:-}" ]] || oc get secret acs-init-credentials -n stackrox &>/dev/null 2>&1; then
  bash "$ROOT/scripts/apply-acs-init-bundle-sync.sh" || true
else
  echo "SKIP apply-acs-init-bundle-sync.sh (export ROX_ADMIN_PASSWORD or create secret acs-init-credentials)"
fi

if [[ -f /tmp/east-kubeconfig || -f /tmp/west-kubeconfig ]]; then
  bash "$ROOT/scripts/apply-ie-anomaly-alerter.sh" || true
fi

if [[ -n "${MAAS_KEY_LLAMA:-}${MAAS_KEY_GRANITE:-}${MAAS_KEY_DEEPSEEK:-}" ]]; then
  bash "$ROOT/scripts/apply-maas-secrets.sh"
else
  echo "SKIP apply-maas-secrets.sh (export MAAS_KEY_LLAMA / GRANITE / DEEPSEEK to inject keys)"
fi

echo ""
echo "== Argo CD application summary =="
oc get applications -n openshift-gitops -o custom-columns=\
NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status \
  2>/dev/null | head -40

echo ""
bash "$ROOT/scripts/verify-workshop-http200.sh"

echo ""
echo "Done. Showroom content: push showroom-hybrid-mesh-ai then:"
echo "  bash scripts/sync-showroom-content.sh   # or oc rollout restart deployment/showroom -n showroom"
