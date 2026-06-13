#!/usr/bin/env bash
# Apply MCP Gateway when Argo sync is Unknown (ACM 2.16). Idempotent.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HUB_DOMAIN="${HUB_DOMAIN:-$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}' 2>/dev/null)}"

if [[ -z "$HUB_DOMAIN" ]]; then
  echo "ERROR: set HUB_DOMAIN or log in to hub" >&2
  exit 1
fi

echo "== MCP Gateway apply (hub: $HUB_DOMAIN) =="
helm template mcp "$ROOT/charts/all/mcp-gateway" \
  --set deployer.domain="$HUB_DOMAIN" \
  --set clusterDomain="$HUB_DOMAIN" \
  | oc apply -f -

echo "Waiting for MCP registrations..."
for _ in $(seq 1 20); do
  READY=$(oc get mcpserverregistration -n mcp-system -o json 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(sum(1 for i in d.get('items',[]) if any(c.get('type')=='Ready' and c.get('status')=='True' for c in i.get('status',{}).get('conditions',[]))))" 2>/dev/null || echo 0)
  echo "  ready registrations: $READY"
  [[ "$READY" -ge 1 ]] && break
  sleep 10
done

CODE=$(curl -sk -o /dev/null -w '%{http_code}' "https://mcp-gateway.$HUB_DOMAIN/mcp" 2>/dev/null || true)
CODE="${CODE:-000}"
CODE="${CODE//$'\r'/}"
echo "mcp-gateway/mcp HTTP: $CODE"
[[ "$CODE" == "200" ]] || { echo "ERROR: MCP gateway not HTTP 200" >&2; exit 1; }
echo "OK: MCP gateway reachable"
