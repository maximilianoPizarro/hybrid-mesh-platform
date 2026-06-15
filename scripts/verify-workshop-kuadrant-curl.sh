#!/usr/bin/env bash
# Smoke-test workshop-apis + ai-gateway (401 without key; 200 with KUADRANT_API_KEY).
set -euo pipefail

HUB_DOMAIN="${HUB_DOMAIN:-$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}' 2>/dev/null || true)}"
MAAS_MODEL="${MAAS_MODEL:-granite-3-2-8b-instruct}"
API_KEY="${KUADRANT_API_KEY:-${WORKSHOP_API_KEY:-}}"

if [[ -z "$HUB_DOMAIN" ]]; then
  echo "ERROR: set HUB_DOMAIN or log in to hub (oc)" >&2
  exit 1
fi

WORKSHOP="https://workshop-apis.$HUB_DOMAIN"
AI="https://ai-gateway.$HUB_DOMAIN"

echo "== Workshop Kuadrant curl verify (hub: $HUB_DOMAIN) =="

check_code() {
  local label="$1" url="$2" expect="$3"
  local code
  code=$(curl -sk -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || echo "000")
  code="${code//$'\r'/}"
  if [[ "$code" == "$expect" ]]; then
    echo "OK  $label → HTTP $code"
  else
    echo "FAIL $label → HTTP $code (expected $expect)" >&2
    return 1
  fi
}

check_post_code() {
  local label="$1" url="$2" body="$3" expect="$4"
  local code
  code=$(curl -sk -o /dev/null -w '%{http_code}' -H "Content-Type: application/json" -X POST "$url" -d "$body" 2>/dev/null || echo "000")
  code="${code//$'\r'/}"
  if [[ "$code" == "$expect" ]]; then
    echo "OK  $label → HTTP $code"
  else
    echo "FAIL $label → HTTP $code (expected $expect)" >&2
    return 1
  fi
}

FAIL=0
check_code "workshop-apis/httpbin (no key)" "$WORKSHOP/httpbin/get" "401" || FAIL=1
check_post_code "ai-gateway/chat (no key)" "$AI/v1/chat/completions" \
  "{\"model\":\"$MAAS_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}],\"max_tokens\":5}" \
  "401" || FAIL=1

if [[ -n "$API_KEY" ]]; then
  echo "-- With API key --"
  code=$(curl -sk -o /dev/null -w '%{http_code}' -H "Authorization: APIKEY $API_KEY" "$WORKSHOP/httpbin/get" 2>/dev/null || echo "000")
  code="${code//$'\r'/}"
  if [[ "$code" == "200" ]]; then
    echo "OK  workshop-apis/httpbin (with key) → HTTP $code"
  else
    echo "FAIL workshop-apis/httpbin (with key) → HTTP $code (expected 200)" >&2
    FAIL=1
  fi
  ai_code=$(curl -sk -o /tmp/ai-gateway-chat.json -w '%{http_code}' \
    -H "Authorization: APIKEY $API_KEY" -H "Content-Type: application/json" \
    -X POST "$AI/v1/chat/completions" \
    -d "{\"model\":\"$MAAS_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Say hi in one word\"}],\"max_tokens\":20}" 2>/dev/null || echo "000")
  ai_code="${ai_code//$'\r'/}"
  if [[ "$ai_code" == "200" ]]; then
    echo "OK  ai-gateway/chat (with key) → HTTP $ai_code"
    head -c 200 /tmp/ai-gateway-chat.json 2>/dev/null | tr -d '\n'; echo
  else
    echo "FAIL ai-gateway/chat (with key) → HTTP $ai_code (expected 200)" >&2
    cat /tmp/ai-gateway-chat.json 2>/dev/null | head -5 || true
    FAIL=1
  fi
else
  echo "SKIP with-key tests (set KUADRANT_API_KEY to verify authenticated calls)"
fi

echo
echo "Request keys: Developer Hub → Kuadrant → API Products → product name → Request API key"
echo "Or: Catalog → API (e.g. workshop-maas-openapi) → Kuadrant tab → Request API key"

exit "$FAIL"
