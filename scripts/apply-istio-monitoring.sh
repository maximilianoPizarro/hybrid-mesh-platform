#!/usr/bin/env bash
# Apply istio-monitoring PodMonitors + UWM on hub and spokes (Argo Unknown workaround).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

apply_cluster() {
  local ctx=$1 suffix=$2
  local kc="/tmp/${ctx}-kubeconfig"
  [[ -f "$kc" ]] || kc="${KUBECONFIG:-}"
  if [[ ! -f "$kc" ]] && [[ "$ctx" != "hub" ]]; then
    echo "SKIP $ctx: no kubeconfig at $kc"
    return 0
  fi
  export KUBECONFIG="$kc"
  echo "== $ctx: observability (UWM) =="
  helm template obs "$ROOT/charts/all/observability" 2>/dev/null | oc apply -f - || true
  echo "== $ctx: istio-monitoring suffix=${suffix:-none} =="
  if [[ -n "$suffix" ]]; then
    helm template im "$ROOT/charts/all/istio-monitoring" --set "clusterSuffix=$suffix" | oc apply -f -
  else
    helm template im "$ROOT/charts/all/istio-monitoring" | oc apply -f -
  fi
}

echo "== Istio monitoring + UWM =="
apply_cluster hub ""
apply_cluster east "-east"
apply_cluster west "-west"
echo "OK: PodMonitors applied — allow 2-3 min for Prometheus scrape"
