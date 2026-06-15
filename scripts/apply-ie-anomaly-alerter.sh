#!/usr/bin/env bash
# Re-apply ie-anomaly-alerter on spokes with hub Mailpit URL (not spoke apps domain).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HUB_DOMAIN="${HUB_DOMAIN:-$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}' 2>/dev/null)}"

if [[ -z "$HUB_DOMAIN" ]]; then
  echo "ERROR: log in to hub or set HUB_DOMAIN" >&2
  exit 1
fi

echo "== IE anomaly alerter (Mailpit on hub: $HUB_DOMAIN) =="

for ctx in east west; do
  kc="/tmp/${ctx}-kubeconfig"
  if [[ ! -f "$kc" ]]; then
    echo "SKIP $ctx: missing $kc"
    continue
  fi
  export KUBECONFIG="$kc"
  echo "-- $ctx --"
  helm template ie "$ROOT/charts/all/ie-anomaly-alerter" \
    --set hubClusterDomain="$HUB_DOMAIN" \
    --set global.hubClusterDomain="$HUB_DOMAIN" \
    --set clusterName="$ctx" | oc apply -f -
  oc rollout restart deploy/ie-anomaly-alerter -n industrial-edge-tst-all
  oc rollout status deploy/ie-anomaly-alerter -n industrial-edge-tst-all --timeout=120s
  oc get deploy ie-anomaly-alerter -n industrial-edge-tst-all \
    -o jsonpath='MAILPIT_URL={.spec.template.spec.containers[0].env[?(@.name=="MAILPIT_URL")].value}{"\n"}'
done

echo "OK: ie-anomaly-alerter pointed at https://mailpit.${HUB_DOMAIN}/api/v1/send"
