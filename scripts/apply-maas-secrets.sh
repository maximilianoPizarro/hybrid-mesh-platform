#!/usr/bin/env bash
# Inject MaaS API keys from env vars (never commit sk-* keys to Git).
#
# When vault-maas-external-secrets is synced (ClusterSecretStore vault-workshop-maas),
# keys are written to Vault and External Secrets Operator syncs K8s Secrets.
# Set USE_VAULT_ESO=0 to force legacy direct oc create secret.
#
# Usage:
#   export MAAS_KEY_LLAMA='sk-...'
#   export MAAS_KEY_GRANITE='sk-...'    # optional
#   export MAAS_KEY_DEEPSEEK='sk-...'   # optional
#   bash scripts/apply-maas-secrets.sh
#
# Skips silently if no keys exported (for optional day-2 step).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAAS_BASE="${MAAS_OPENAI_API_BASE:-https://maas-rhdp.apps.maas.redhatworkshops.io/v1}"
APPLIED=0
USE_VAULT_ESO="${USE_VAULT_ESO:-auto}"

apply_secret() {
  local name=$1 ns=$2 key=$3
  [[ -n "$key" ]] || return 0
  oc create secret generic "$name" -n "$ns" \
    --from-literal=api-key="$key" \
    --dry-run=client -o yaml | oc apply -f -
  echo "  applied $ns/$name"
  APPLIED=$((APPLIED + 1))
}

force_eso_sync() {
  local ns=$1
  local es
  for es in $(oc get externalsecret -n "$ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true); do
    [[ -n "$es" ]] || continue
    oc annotate externalsecret "$es" -n "$ns" \
      "force-sync.external-secrets.io/$(date +%s)=true" --overwrite 2>/dev/null || \
      oc annotate externalsecret "$es" -n "$ns" \
      "reconcile.external-secrets.io/request-id=$(date +%s)" --overwrite 2>/dev/null || true
    echo "  requested ESO sync $ns/$es"
  done
}

if [[ -z "${MAAS_KEY_LLAMA:-}" && -z "${MAAS_KEY_GRANITE:-}" && -z "${MAAS_KEY_DEEPSEEK:-}" ]]; then
  echo "SKIP: no MAAS_KEY_* env vars set — export keys and re-run"
  exit 0
fi

if [[ "$USE_VAULT_ESO" == "auto" ]]; then
  if oc get clustersecretstore vault-workshop-maas >/dev/null 2>&1; then
    USE_VAULT_ESO=1
  else
    USE_VAULT_ESO=0
  fi
fi

if [[ "$USE_VAULT_ESO" == "1" ]]; then
  echo "== MaaS via Vault + External Secrets (keys not printed) =="
  bash "$ROOT/scripts/seed-maas-vault.sh"

  echo ""
  echo "== Force ExternalSecret refresh =="
  for NS in ai-gateway-system kairos-system maas-workshop neuroface developer-hub; do
    force_eso_sync "$NS"
  done

  echo ""
  echo "== Patch NeuroFace env (if needed) =="
  if [[ -n "${MAAS_KEY_LLAMA:-}" ]]; then
    if ! oc get deploy neuroface-backend -n neuroface -o jsonpath='{.spec.template.spec.containers[0].env[*].name}' 2>/dev/null | tr ' ' '\n' | grep -qFx NEUROFACE_CHAT_API_KEY; then
      oc patch deployment neuroface-backend -n neuroface --type=json -p='[
        {"op":"add","path":"/spec/template/spec/containers/0/env/-","value":{
          "name":"NEUROFACE_CHAT_API_KEY",
          "valueFrom":{"secretKeyRef":{"name":"neuroface-maas-api-key","key":"api-key"}}
        }}
      ]' 2>/dev/null || oc patch deployment neuroface-backend -n neuroface --type=json -p='[
        {"op":"add","path":"/spec/template/spec/containers/0/env","value":[
          {"name":"NEUROFACE_CHAT_API_KEY","valueFrom":{"secretKeyRef":{"name":"neuroface-maas-api-key","key":"api-key"}}}
        ]}
      ]'
    fi
  fi

  echo ""
  echo "== AuthPolicy Bearer sync (one-shot) =="
  oc delete job maas-authpolicy-sync-once -n ai-gateway-system --ignore-not-found
  if oc get cronjob maas-authpolicy-sync -n ai-gateway-system >/dev/null 2>&1; then
    oc create job maas-authpolicy-sync-once --from=cronjob/maas-authpolicy-sync -n ai-gateway-system
    oc wait job/maas-authpolicy-sync-once -n ai-gateway-system --for=condition=Complete --timeout=120s 2>/dev/null || true
  fi

  echo ""
  echo "== Restart workloads =="
  oc rollout restart deployment/neuroface-backend -n neuroface 2>/dev/null || true
  oc rollout restart deployment/developer-hub -n developer-hub 2>/dev/null || true

  echo "Vault + ESO path complete. Verify: oc get externalsecret -A"
  exit 0
fi

echo "== MaaS secrets legacy mode (direct K8s Secret; keys not printed) =="

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
  if ! oc get deploy neuroface-backend -n neuroface -o jsonpath='{.spec.template.spec.containers[0].env[*].name}' 2>/dev/null | tr ' ' '\n' | grep -qFx NEUROFACE_CHAT_API_KEY; then
    oc patch deployment neuroface-backend -n neuroface --type=json -p='[
      {"op":"add","path":"/spec/template/spec/containers/0/env/-","value":{
        "name":"NEUROFACE_CHAT_API_KEY",
        "valueFrom":{"secretKeyRef":{"name":"neuroface-maas-api-key","key":"api-key"}}
      }}
    ]' 2>/dev/null || oc patch deployment neuroface-backend -n neuroface --type=json -p='[
      {"op":"add","path":"/spec/template/spec/containers/0/env","value":[
        {"name":"NEUROFACE_CHAT_API_KEY","valueFrom":{"secretKeyRef":{"name":"neuroface-maas-api-key","key":"api-key"}}}
      ]}
    ]'
  fi
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
oc rollout restart deployment/neuroface-backend -n neuroface 2>/dev/null || true
oc rollout restart deployment/developer-hub -n developer-hub 2>/dev/null || true

if oc get job developer-hub-lightspeed-ai-sync -n developer-hub >/dev/null 2>&1; then
  oc delete job developer-hub-lightspeed-ai-sync -n developer-hub --ignore-not-found
fi

echo "Applied $APPLIED secret group(s). Verify: NeuroFace /api/chat and Developer Hub /lightspeed"
