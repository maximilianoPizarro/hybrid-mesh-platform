#!/usr/bin/env bash
# Validate NeuroFace CV path: spoke yolo-ppe-serving → Skupper → neuroface-gateway → public Route.
set -euo pipefail

TIMEOUT="${CURL_TIMEOUT:-10}"
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

echo "=== Skupper listeners (hub) ==="
oc get listener -n service-interconnect 2>/dev/null | grep -E 'neuroface-cv|NAME' || true

echo ""
echo "=== Hub neuroface-gateway ==="
oc get gateway neuroface-gateway -n neuroface-gateway-system 2>/dev/null || echo "WARN: Gateway neuroface-gateway missing"
oc get httproute neuroface-cv-lb -n neuroface-gateway-system 2>/dev/null || echo "WARN: HTTPRoute neuroface-cv-lb missing"
oc get svc neuroface-gateway-istio -n neuroface-gateway-system 2>/dev/null || echo "WARN: Service neuroface-gateway-istio missing"
GW_EP="$(oc get endpoints neuroface-gateway-istio -n neuroface-gateway-system -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null || true)"
if [[ -z "$GW_EP" ]]; then
  echo "WARN: neuroface-gateway-istio has no endpoints"
  fail=1
else
  echo "neuroface-gateway-istio endpoint: ${GW_EP}"
fi

echo ""
echo "=== HTTP checks (hub) ==="
CV_URL="https://neuroface-cv.${HUB_DOMAIN}/api/ppe/status"
CV_CODE="$(curl -sk -o /dev/null -w '%{http_code}' --connect-timeout "$TIMEOUT" "$CV_URL" 2>/dev/null || echo "000")"
echo "neuroface-cv status: ${CV_CODE} ${CV_URL}"
[[ "$CV_CODE" =~ ^2 ]] || fail=1

HEALTH_URL="https://neuroface-cv.${HUB_DOMAIN}/health"
HEALTH_CODE="$(curl -sk -o /dev/null -w '%{http_code}' --connect-timeout "$TIMEOUT" "$HEALTH_URL" 2>/dev/null || echo "000")"
echo "neuroface-cv health: ${HEALTH_CODE} ${HEALTH_URL}"
[[ "$HEALTH_CODE" =~ ^2 ]] || fail=1

echo ""
echo "=== Spoke PPE deployments (optional kubeconfigs) ==="
for pair in east:"${EAST_DOMAIN:-}" west:"${WEST_DOMAIN:-}"; do
  cluster="${pair%%:*}"
  domain="${pair#*:}"
  kc="/tmp/${cluster}-kubeconfig"
  if [[ -f "$kc" ]]; then
    isvc_ready="$(oc --kubeconfig="$kc" get inferenceservice yolo-ppe-serving -n neuroface-cv -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
    if [[ "$isvc_ready" == "True" ]]; then
      echo "${cluster} yolo-ppe-serving InferenceService Ready (domain=${domain:-n/a})"
    else
      ready="$(oc --kubeconfig="$kc" get deploy yolo-ppe-serving-predictor -n neuroface-cv -o jsonpath='{.status.readyReplicas}' 2>/dev/null || oc --kubeconfig="$kc" get deploy yolo-ppe-serving -n neuroface-cv -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")"
      echo "${cluster} yolo-ppe-serving readyReplicas=${ready:-0} (domain=${domain:-n/a})"
      [[ "${ready:-0}" -ge 1 ]] || { echo "WARN: ${cluster} yolo-ppe-serving not ready"; fail=1; }
    fi
  else
    echo "skip ${cluster}: no ${kc}"
  fi
done

if (( fail > 0 )); then
  echo ""
  echo "NeuroFace CV validation FAILED"
  exit 1
fi
echo ""
echo "NeuroFace CV validation OK"
