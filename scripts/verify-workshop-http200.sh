#!/usr/bin/env bash
# Strict HTTP 200 smoke test: console links + workshop/AI URLs (hub + spokes).
# Requires: oc logged in on hub; optional /tmp/{hub,east,west}-kubeconfig for spokes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0

hub_domain() {
  oc get ingresses.config/cluster -o jsonpath='{.spec.domain}' 2>/dev/null
}

cluster_apps_domain() {
  local name=$1
  local console
  console="$(oc get managedcluster "$name" -o jsonpath='{.status.clusterClaims[?(@.name=="consoleurl.cluster.open-cluster-management.io")].value}' 2>/dev/null || true)"
  [[ -n "$console" && "$console" =~ apps\.[^/]+ ]] && echo "${BASH_REMATCH[0]}"
}

check() {
  local label=$1 url=$2 auth=${3:-}
  local code
  if [[ "$auth" == token ]]; then
    code=$(curl -sk -o /dev/null -w '%{http_code}' -H "Authorization: Bearer ${TOKEN}" \
      --connect-timeout "${CURL_TIMEOUT:-10}" "$url" 2>/dev/null || true)
  else
    code=$(curl -sk -o /dev/null -w '%{http_code}' --connect-timeout "${CURL_TIMEOUT:-10}" "$url" 2>/dev/null || true)
  fi
  code="${code:-000}"
  code="${code//$'\r'/}"
  if [[ "$code" == "200" ]]; then
    printf 'OK  200  %s\n' "$label"
  else
    printf 'FAIL %-3s %s\n' "$code" "$label"
    FAIL=$((FAIL + 1))
  fi
}

check_expect() {
  local label=$1 url=$2 expect=$3
  local code
  code=$(curl -sk -o /dev/null -w '%{http_code}' --connect-timeout "${CURL_TIMEOUT:-10}" "$url" 2>/dev/null || true)
  code="${code:-000}"
  code="${code//$'\r'/}"
  if [[ "$code" == "$expect" ]]; then
    printf 'OK  %-3s %s\n' "$code" "$label"
  else
    printf 'FAIL %-3s (want %s) %s\n' "$code" "$expect" "$label"
    FAIL=$((FAIL + 1))
  fi
}

HUB="${HUB_DOMAIN:-$(hub_domain)}"
if [[ -z "$HUB" ]]; then
  echo "ERROR: log in to hub or set HUB_DOMAIN" >&2
  exit 1
fi

TOKEN="$(oc whoami -t 2>/dev/null || true)"

echo "== Console links (MIN_OK_CODE=200) =="
if ! MIN_OK_CODE=200 bash "$ROOT/scripts/verify-console-links.sh"; then
  FAIL=$((FAIL + 1))
fi

echo ""
echo "== Workshop + AI (hub: $HUB) =="
check showroom "https://showroom-showroom.$HUB/"
check registration "https://workshop-registration.$HUB/"
check developer-hub "https://developer-hub.$HUB/"
check lightspeed "https://developer-hub.$HUB/lightspeed"
check kafka-console "https://kafka-console.$HUB/"
check neuroface "https://neuroface.$HUB/"
check industrial-edge "https://industrial-edge.$HUB/"
check skupper-observer "https://skupper-network-observer-service-interconnect.$HUB/"
check mcp-gateway "https://mcp-gateway.$HUB/mcp"
check_expect workshop-apis-no-key "https://workshop-apis.$HUB/httpbin/get" "401"
check vault-ui "https://vault-vault.$HUB/ui/"
check grafana "https://grafana.$HUB/"
check ods-dashboard "https://rhods-dashboard-redhat-ods-applications.$HUB/" token

EAST="${EAST_DOMAIN:-$(cluster_apps_domain east)}"
WEST="${WEST_DOMAIN:-$(cluster_apps_domain west)}"

if [[ -n "${EAST:-}" ]]; then
  echo ""
  echo "== Spokes (east: $EAST) =="
  check devspaces-east "https://devspaces.$EAST/"
  check line-dashboard-east "https://line-dashboard-industrial-edge-tst-all.$EAST/"
fi

if [[ -n "${WEST:-}" ]]; then
  echo ""
  echo "== Spokes (west: $WEST) =="
  check devspaces-west "https://devspaces.$WEST/"
fi

echo ""
if (( FAIL > 0 )); then
  echo "FAILED: $FAIL check(s) did not return HTTP 200" >&2
  exit 1
fi
echo "OK: all workshop HTTP 200 checks passed"
