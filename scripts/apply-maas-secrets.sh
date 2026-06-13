#!/usr/bin/env bash
# Inject MaaS API keys from env vars (never commit sk-* keys to Git).
#
# Usage:
#   export MAAS_KEY_LLAMA='sk-...'
#   export MAAS_KEY_GRANITE='sk-...'    # optional
#   export MAAS_KEY_DEEPSEEK='sk-...'   # optional
#   bash scripts/apply-maas-secrets.sh
#
# Skips silently if no keys exported (for optional day-2 step).
set -euo pipefail

MAAS_BASE="${MAAS_OPENAI_API_BASE:-https://maas-rhdp.apps.maas.redhatworkshops.io/v1}"
APPLIED=0

apply_secret() {
  local name=$1 ns=$2 key=$3
  [[ -n "$key" ]] || return 0
  oc create secret generic "$name" -n "$ns" \
    --from-literal=api-key="$key" \
    --dry-run=client -o yaml | oc apply -f -
  echo "  applied $ns/$name"
  APPLIED=$((APPLIED + 1))
}

if [[ -z "${MAAS_KEY_LLAMA:-}" && -z "${MAAS_KEY_GRANITE:-}" && -z "${MAAS_KEY_DEEPSEEK:-}" ]]; then
  echo "SKIP: no MAAS_KEY_* env vars set — export keys and re-run"
  exit 0
fi

echo "== MaaS secrets (keys not printed) =="

if [[ -n "${MAAS_KEY_LLAMA:-}" ]]; then
  oc create secret generic kairos-ai-credentials -n kairos-system \
    --from-literal=api-key="$MAAS_KEY_LLAMA" \
    --dry-run=client -o yaml | oc apply -f -
  echo "  applied kairos-system/kairos-ai-credentials"
  oc create secret generic openshift-ai-maas-credentials -n maas-workshop \
    --from-literal=api-key="$MAAS_KEY_LLAMA" \
    --from-literal=OPENAI_API_BASE="$MAAS_BASE" \
    --dry-run=client -o yaml | oc apply -f -
  echo "  applied maas-workshop/openshift-ai-maas-credentials"
  apply_secret neuroface-maas-api-key neuroface "$MAAS_KEY_LLAMA"
  LS_KEY="${MAAS_KEY_GRANITE:-$MAAS_KEY_LLAMA}"
  oc patch secret llama-stack-secrets -n developer-hub --type merge \
    -p "{\"stringData\":{\"VLLM_API_KEY\":\"${LS_KEY}\"}}" 2>/dev/null || true
  echo "  patched developer-hub/llama-stack-secrets VLLM_API_KEY"
  APPLIED=$((APPLIED + 1))
fi

if [[ -n "${MAAS_KEY_GRANITE:-}" ]]; then
  oc create secret generic maas-granite-credentials -n maas-workshop \
    --from-literal=api-key="$MAAS_KEY_GRANITE" \
    --from-literal=OPENAI_API_BASE="$MAAS_BASE" \
    --from-literal=model=granite-3-2-8b-instruct \
    --dry-run=client -o yaml | oc apply -f -
  echo "  applied maas-workshop/maas-granite-credentials"
  APPLIED=$((APPLIED + 1))
fi

if [[ -n "${MAAS_KEY_DEEPSEEK:-}" ]]; then
  oc create secret generic maas-deepseek-credentials -n maas-workshop \
    --from-literal=api-key="$MAAS_KEY_DEEPSEEK" \
    --from-literal=OPENAI_API_BASE="$MAAS_BASE" \
    --from-literal=model=deepseek-r1-distill-qwen-14b \
    --dry-run=client -o yaml | oc apply -f -
  echo "  applied maas-workshop/maas-deepseek-credentials"
  APPLIED=$((APPLIED + 1))
fi

echo ""
echo "== Restart workloads =="
oc rollout restart deployment/neuroface -n neuroface 2>/dev/null || true
oc rollout restart deployment/developer-hub -n developer-hub 2>/dev/null || true

if oc get job developer-hub-lightspeed-ai-sync -n developer-hub >/dev/null 2>&1; then
  oc delete job developer-hub-lightspeed-ai-sync -n developer-hub --ignore-not-found
fi

echo "Applied $APPLIED secret group(s). Verify: NeuroFace /api/chat and Developer Hub /lightspeed"
