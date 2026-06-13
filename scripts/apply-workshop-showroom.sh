#!/usr/bin/env bash
# Deploy Workshop Showroom when Argo CD sync is Unknown (ACM 2.16 clusterview schema).
# Idempotent: safe to re-run after fleet-values-sync updates east/west domains.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-600}"

if ! command -v oc >/dev/null 2>&1; then
  echo "ERROR: oc not found" >&2
  exit 1
fi
if ! command -v helm >/dev/null 2>&1; then
  echo "ERROR: helm not found" >&2
  exit 1
fi

hub_domain() {
  oc get ingresses.config/cluster -o jsonpath='{.spec.domain}' 2>/dev/null
}

cluster_api_url() {
  local name="$1"
  oc get managedcluster "$name" -o jsonpath='{.status.clusterClaims[?(@.name=="apiserverurl.openshift.io")].value}' 2>/dev/null
}

cluster_apps_domain() {
  local name="$1"
  local console
  console="$(oc get managedcluster "$name" -o jsonpath='{.status.clusterClaims[?(@.name=="consoleurl.cluster.open-cluster-management.io")].value}' 2>/dev/null || true)"
  if [[ -n "$console" && "$console" =~ apps\.[^/]+ ]]; then
    echo "${BASH_REMATCH[0]}"
    return
  fi
  echo ""
}

HUB_DOMAIN="${HUB_DOMAIN:-$(hub_domain)}"
if [[ -z "$HUB_DOMAIN" ]]; then
  echo "ERROR: set HUB_DOMAIN or log in to the hub cluster" >&2
  exit 1
fi

HUB_API="${HUB_API:-$(cluster_api_url local-cluster)}"
if [[ -z "$HUB_API" ]]; then
  HUB_API="https://api.${HUB_DOMAIN#apps.}:6443"
fi

EAST_DOMAIN="${EAST_DOMAIN:-$(cluster_apps_domain east)}"
WEST_DOMAIN="${WEST_DOMAIN:-$(cluster_apps_domain west)}"
EAST_API="${EAST_API:-$(cluster_api_url east)}"
WEST_API="${WEST_API:-$(cluster_api_url west)}"

echo "== Workshop Showroom apply =="
echo "hub:  $HUB_DOMAIN  $HUB_API"
echo "east: ${EAST_DOMAIN:-<unset>}  ${EAST_API:-<unset>}"
echo "west: ${WEST_DOMAIN:-<unset>}  ${WEST_API:-<unset>}"

helm template showroom "$ROOT/charts/all/showroom" \
  --set deployer.domain="$HUB_DOMAIN" \
  --set deployer.apiUrl="$HUB_API" \
  --set clusters.hub.domain="$HUB_DOMAIN" \
  --set clusters.hub.apiUrl="$HUB_API" \
  --set clusters.east.domain="${EAST_DOMAIN:-}" \
  --set clusters.east.apiUrl="${EAST_API:-}" \
  --set clusters.west.domain="${WEST_DOMAIN:-}" \
  --set clusters.west.apiUrl="${WEST_API:-}" \
  --set registration.url="https://workshop-registration.$HUB_DOMAIN" \
  | oc apply -f -

echo "Waiting for showroom deployment (init containers may take several minutes)..."
oc rollout status deployment/showroom -n showroom --timeout="${WAIT_TIMEOUT}s"

SHOWROOM_URL="https://showroom-showroom.$HUB_DOMAIN/"
CODE="$(curl -sk -o /dev/null -w '%{http_code}' "$SHOWROOM_URL" 2>/dev/null || echo "000")"
echo "showroom HTTP: $CODE  $SHOWROOM_URL"

if [[ ! "$CODE" =~ ^2 ]]; then
  echo "ERROR: showroom did not return HTTP 2xx" >&2
  oc get pods -n showroom -l app.kubernetes.io/name=showroom
  exit 1
fi

echo "OK: Workshop Showroom is reachable"
echo "Registration: https://workshop-registration.$HUB_DOMAIN/"
