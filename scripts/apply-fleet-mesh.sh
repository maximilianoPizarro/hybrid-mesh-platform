#!/usr/bin/env bash
# Bootstrap Skupper VAN + OSSM 3.2 when Argo CD sync is Unknown (ACM 2.16).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v oc >/dev/null 2>&1 || ! command -v helm >/dev/null 2>&1; then
  echo "ERROR: oc and helm required" >&2
  exit 1
fi

hub_domain() {
  oc get ingresses.config/cluster -o jsonpath='{.spec.domain}' 2>/dev/null
}

cluster_apps_domain() {
  local console
  console="$(oc get managedcluster "$1" -o jsonpath='{.status.clusterClaims[?(@.name=="consoleurl.cluster.open-cluster-management.io")].value}' 2>/dev/null || true)"
  [[ -n "$console" && "$console" =~ apps\.[^/]+ ]] && echo "${BASH_REMATCH[0]}"
}

HUB_DOMAIN="${HUB_DOMAIN:-$(hub_domain)}"
EAST_DOMAIN="${EAST_DOMAIN:-$(cluster_apps_domain east)}"
WEST_DOMAIN="${WEST_DOMAIN:-$(cluster_apps_domain west)}"

if [[ -z "$HUB_DOMAIN" ]]; then
  echo "ERROR: set HUB_DOMAIN or log in to hub" >&2
  exit 1
fi

SUB=$(cat <<'EOF'
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: servicemeshoperator3
  namespace: openshift-operators
spec:
  channel: stable-3.2
  installPlanApproval: Automatic
  name: servicemeshoperator3
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
)

wait_istiod() {
  local ctx=$1
  export KUBECONFIG="${SPOKE_KUBECONFIG:-/tmp/${ctx}-kubeconfig}"
  [[ -f "$KUBECONFIG" ]] || return 0
  echo "Waiting for istiod on $ctx..."
  for _ in $(seq 1 30); do
    local ready
    ready=$(oc get pods -n istio-system -l app=istiod --no-headers 2>/dev/null | awk '$3=="Running"{n++} END{print n+0}')
    local gc
    gc=$(oc get gatewayclass istio --no-headers 2>/dev/null | wc -l)
    echo "  istiod=$ready gatewayclass=$gc"
    [[ "$ready" -ge 1 && "$gc" -ge 1 ]] && return 0
    sleep 20
  done
  echo "WARN: istiod not Ready on $ctx" >&2
  return 1
}

apply_spoke() {
  local ctx=$1 cn=$2
  local kc="${SPOKE_KUBECONFIG:-/tmp/${ctx}-kubeconfig}"
  [[ -f "$kc" ]] || { echo "WARN: skip $ctx (no $kc)"; return 0; }
  export KUBECONFIG="$kc"
  echo "== $ctx: Service Mesh operator =="
  echo "$SUB" | oc apply -f -
  wait_istiod "$ctx" || true
  echo "== $ctx: servicemeshoperator3 =="
  helm template sm "$ROOT/charts/all/servicemeshoperator3" \
    --set clusterName="$cn" --set clusterRole=spoke \
    | oc apply -f -
  wait_istiod "$ctx" || true
  echo "== $ctx: spoke-interconnect =="
  helm template si "$ROOT/charts/all/spoke-interconnect" \
    --set clusterName="$cn" \
    --set clusterDomain="${!ctx_domain}" \
    --set hubClusterDomain="$HUB_DOMAIN" \
    | oc apply -f -
  echo "== $ctx: spoke-gateway + industrial-edge-tst =="
  helm template sg "$ROOT/charts/all/spoke-gateway" \
    --set clusterName="$cn" --set clusterDomain="${!ctx_domain}" --set hubClusterDomain="$HUB_DOMAIN" \
    | oc apply -f -
  helm template ie "$ROOT/charts/all/industrial-edge-tst" \
    --set clusterName="$cn" --set clusterDomain="${!ctx_domain}" --set clusterRole=spoke \
    --set global.localClusterDomain="${!ctx_domain}" --set global.hubClusterDomain="$HUB_DOMAIN" \
    | oc apply -f -
  oc rollout restart deployment/line-dashboard -n industrial-edge-tst-all 2>/dev/null || true
}

east_domain="$EAST_DOMAIN"
west_domain="$WEST_DOMAIN"
apply_spoke east east
apply_spoke west west

export KUBECONFIG="${HUB_KUBECONFIG:-/tmp/hub-kubeconfig}"
echo "== hub: Service Mesh operator =="
echo "$SUB" | oc apply -f -
wait_istiod hub || true
echo "== hub: servicemeshoperator3 =="
helm template sm "$ROOT/charts/all/servicemeshoperator3" --set clusterRole=hub | oc apply -f -
wait_istiod hub || true
echo "== hub: remove legacy nginx hub-gateway (use Istio Gateway API + waypoint) =="
if [[ "${SKIP_NGINX_CLEANUP:-}" != "1" ]]; then
  oc delete deployment hub-gateway-istio -n hub-gateway-system --ignore-not-found
  oc delete configmap hub-gateway-proxy-config -n hub-gateway-system --ignore-not-found
  # Legacy nginx Service used app=hub-gateway-istio; Istio gateway pods use gateway.networking.k8s.io/gateway-name.
  oc delete svc hub-gateway-istio -n hub-gateway-system --ignore-not-found
fi
echo "== hub: hub-gateway (Istio Gateway API + waypoint) =="
helm template hg "$ROOT/charts/all/hub-gateway" \
  --set clusterDomain="$HUB_DOMAIN" \
  --set clusters.east.domain="${EAST_DOMAIN:-}" \
  --set clusters.west.domain="${WEST_DOMAIN:-}" \
  | oc apply -f -

echo "== hub: Skupper token sync =="
oc delete job skupper-accesstoken-sync-manual -n service-interconnect --ignore-not-found
oc create job --from=cronjob/skupper-accesstoken-sync skupper-accesstoken-sync-manual -n service-interconnect

echo "Waiting for Skupper VAN..."
for _ in $(seq 1 30); do
  SITES=$(oc get site hub -n service-interconnect -o jsonpath='{.status.sitesInNetwork}' 2>/dev/null || echo 0)
  echo "sitesInNetwork=$SITES"
  [[ "$SITES" == "3" ]] && break
  sleep 20
done

HUB_DOMAIN="$HUB_DOMAIN" EAST_DOMAIN="$EAST_DOMAIN" WEST_DOMAIN="$WEST_DOMAIN" \
  bash "$ROOT/scripts/verify-industrial-edge.sh"
