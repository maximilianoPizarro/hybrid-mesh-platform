#!/usr/bin/env bash
# Apply workshop Kuadrant APIs when Argo sync is Unknown (ACM 2.16). Idempotent.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HUB_DOMAIN="${HUB_DOMAIN:-$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}' 2>/dev/null)}"
MAAS_KEY="${MAAS_KEY_LLAMA:-${LITEMAAS_API_KEY:-}}"

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

HOST="workshop-apis.$HUB_DOMAIN"
CODE=$(curl -sk -o /dev/null -w '%{http_code}' "https://$HOST/httpbin/get" 2>/dev/null || true)
CODE="${CODE:-000}"
CODE="${CODE//$'\r'/}"
echo "workshop-apis/httpbin (no API key): HTTP $CODE (expect 401)"
[[ "$CODE" == "401" || "$CODE" == "403" ]] || echo "WARN: expected 401 without APIKEY header"
echo "OK: workshop Kuadrant APIs applied — request keys at Developer Hub /kuadrant"
