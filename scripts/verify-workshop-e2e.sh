#!/usr/bin/env bash
# Workshop platform wiring checks (VP layout).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOMAIN="${HUB_DOMAIN:-apps.test.example.com}"

echo "== helm template VP charts (workshop) =="
helm template showroom "$ROOT/charts/all/showroom" --set deployer.domain="$DOMAIN" >/dev/null
helm template reg "$ROOT/charts/all/workshop-registration" --set deployer.domain="$DOMAIN" >/dev/null
helm template wd "$ROOT/charts/all/workshop-demos" \
  --set clusterDomain="$DOMAIN" --set hubClusterDomain="$DOMAIN" \
  --set eastClusterDomain="apps.east.example.com" >/dev/null
helm template nf "$ROOT/charts/all/neuroface" \
  --set clusterDomain="$DOMAIN" --set neuroface.route.host="neuroface.$DOMAIN" >/dev/null
helm template cl "$ROOT/charts/all/console-links" \
  --set clusterDomain="$DOMAIN" --set hubClusterDomain="$DOMAIN" \
  --set clusterRole=hub | grep -q "platform-hybrid-mesh-workshop"

echo "== gitops strategies =="
python3 "$ROOT/scripts/verify-gitops-strategies.py"

echo "OK: workshop VP charts render"
