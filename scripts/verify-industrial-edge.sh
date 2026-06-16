#!/usr/bin/env bash
# Validate Industrial Edge path: spoke line-dashboard → Skupper → hub-gateway → public Route.
set -euo pipefail

TIMEOUT="${CURL_TIMEOUT:-5}"
HUB_DOMAIN="${HUB_DOMAIN:-}"
EAST_DOMAIN="${EAST_DOMAIN:-}"
WEST_DOMAIN="${WEST_DOMAIN:-}"

if ! command -v oc >/dev/null 2>&1; then
  echo "ERROR: oc not found" >&2
  exit 1
fi

if [[ -z "$HUB_DOMAIN" ]]; then
  HUB_DOMAIN="$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}' 2>/dev/null || true)"
fi
if [[ -z "$HUB_DOMAIN" ]]; then
  echo "ERROR: set HUB_DOMAIN or log in to hub cluster" >&2
  exit 1
fi

fail=0

echo "=== Skupper VAN (hub) ==="
SITES="$(oc get site hub -n service-interconnect -o jsonpath='{.status.sitesInNetwork}' 2>/dev/null || echo "?")"
echo "sitesInNetwork=${SITES}"
oc get listener -n service-interconnect 2>/dev/null | grep -E 'ie-gateway|NAME' || true

echo ""
echo "=== Hub gateway ==="
oc get gateway hub-gateway -n hub-gateway-system 2>/dev/null || echo "WARN: Gateway hub-gateway missing"
oc get svc hub-gateway-istio -n hub-gateway-system 2>/dev/null || echo "WARN: Service hub-gateway-istio missing (Istio not reconciled?)"
GW_EP="$(oc get endpoints hub-gateway-istio -n hub-gateway-system -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null || true)"
if [[ -z "$GW_EP" ]]; then
  echo "WARN: hub-gateway-istio has no endpoints — refresh hub-post-install-bootstrap PostSync job"
  fail=1
else
  echo "hub-gateway-istio endpoint: ${GW_EP}"
fi
oc get gateway hub-gateway-system-waypoint -n hub-gateway-system -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}{"\n"}' 2>/dev/null | grep -qx True && echo "hub-gateway waypoint: Programmed" || echo "WARN: hub-gateway-system-waypoint not Programmed"

echo ""
echo "=== HTTP checks ==="
IE_URL="https://industrial-edge.${HUB_DOMAIN}/"
IE_CODE="$(curl -sk -o /dev/null -w '%{http_code}' --connect-timeout "$TIMEOUT" "$IE_URL" 2>/dev/null || echo "000")"
echo "hub IE route: ${IE_CODE} ${IE_URL}"

if [[ -n "$EAST_DOMAIN" ]]; then
  EAST_URL="https://line-dashboard-industrial-edge-tst-all.${EAST_DOMAIN}/"
  EAST_CODE="$(curl -sk -o /dev/null -w '%{http_code}' --connect-timeout "$TIMEOUT" "$EAST_URL" 2>/dev/null || echo "000")"
  echo "east line-dashboard: ${EAST_CODE} ${EAST_URL}"
  [[ "$EAST_CODE" =~ ^[23] ]] || fail=1
fi

if [[ -n "$WEST_DOMAIN" ]]; then
  WEST_URL="https://line-dashboard-industrial-edge-tst-all.${WEST_DOMAIN}/"
  WEST_CODE="$(curl -sk -o /dev/null -w '%{http_code}' --connect-timeout "$TIMEOUT" "$WEST_URL" 2>/dev/null || echo "000")"
  echo "west line-dashboard: ${WEST_CODE} ${WEST_URL}"
  [[ "$WEST_CODE" =~ ^[23] ]] || fail=1
fi

[[ "$IE_CODE" =~ ^2 ]] || fail=1
[[ "$SITES" == "3" ]] || { echo "WARN: expected sitesInNetwork=3"; fail=1; }

if (( fail > 0 )); then
  echo ""
  echo "Industrial Edge validation FAILED"
  exit 1
fi
echo ""
echo "Industrial Edge validation OK"
