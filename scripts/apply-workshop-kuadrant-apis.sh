#!/usr/bin/env bash
# Apply workshop Kuadrant APIs when Argo sync is Unknown (ACM 2.16). Idempotent.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HUB_DOMAIN="${HUB_DOMAIN:-$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}' 2>/dev/null)}"
MAAS_KEY="${MAAS_KEY_LLAMA:-${LITEMAAS_API_KEY:-}}"

if [[ -z "$MAAS_KEY" ]]; then
  MAAS_KEY="$(oc get application field-content -n openshift-gitops -o jsonpath='{.spec.source.helm.valuesObject.litemaas.apiKey}' 2>/dev/null || true)"
  if [[ -z "$MAAS_KEY" ]]; then
    MAAS_KEY="$(oc get application field-content -n openshift-gitops -o yaml 2>/dev/null | grep -A1 'apiKey:' | tail -1 | sed 's/.*: //;s/"//g' || true)"
  fi
fi

if [[ -z "$HUB_DOMAIN" ]]; then
  echo "ERROR: set HUB_DOMAIN or log in to hub" >&2
  exit 1
fi

echo "== Workshop Kuadrant APIs (hub: $HUB_DOMAIN) =="
SET_ARGS=(--set "deployer.domain=$HUB_DOMAIN" --set "clusterDomain=$HUB_DOMAIN")
if [[ -n "$MAAS_KEY" ]]; then
  SET_ARGS+=(--set "apis.maas.apiKey=$MAAS_KEY")
fi

helm template wka "$ROOT/charts/all/workshop-kuadrant-apis" "${SET_ARGS[@]}" | oc apply -f -

echo "Restarting Kuadrant operator (Gateway API provider detection runs at pod startup)..."
oc rollout restart deployment/kuadrant-operator-controller-manager -n redhat-connectivity-link-operator 2>/dev/null || true
oc rollout status deployment/kuadrant-operator-controller-manager -n redhat-connectivity-link-operator --timeout=180s 2>/dev/null || true
for _ in $(seq 1 24); do
  ready=$(oc get kuadrant kuadrant -n kuadrant-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
  [[ "$ready" == "True" ]] && break
  sleep 5
done

WORKSHOP_HOST="workshop-apis.$HUB_DOMAIN"
AI_HOST="ai-gateway.$HUB_DOMAIN"
CODE=$(curl -sk -o /dev/null -w '%{http_code}' "https://$WORKSHOP_HOST/httpbin/get" 2>/dev/null || true)
CODE="${CODE:-000}"
CODE="${CODE//$'\r'/}"
echo "workshop-apis/httpbin (no API key): HTTP $CODE (expect 401)"
AI_CODE=$(curl -sk -o /dev/null -w '%{http_code}' "https://$AI_HOST/v1/models" 2>/dev/null || true)
AI_CODE="${AI_CODE:-000}"
echo "ai-gateway/v1/models (no API key): HTTP ${AI_CODE//$'\r'/} (expect 401)"
[[ "$CODE" == "401" || "$CODE" == "403" ]] || echo "WARN: expected 401 without APIKEY on workshop-apis"
bash "$(cd "$(dirname "$0")/.." && pwd)/scripts/sync-kuadrant-apiproduct-plans.sh" 2>/dev/null || true
echo "OK: workshop-apis + ai-gateway applied — request keys at Developer Hub /kuadrant"
