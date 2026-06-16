#!/usr/bin/env bash
# Day-2: ACS init bundle credentials + re-trigger hub/spoke cluster registration in Central.
#
# Prerequisites:
#   - oc logged in to hub (cluster-admin)
#   - ACS Central installed (acs-operator synced)
#   - Optional: export ROX_ADMIN_PASSWORD (Central admin password)
#
# Usage:
#   export ROX_ADMIN_PASSWORD='...'
#   bash scripts/apply-acs-init-bundle-sync.sh
set -euo pipefail

NS="${ACS_NAMESPACE:-stackrox}"
SECRET="${ACS_CREDENTIALS_SECRET:-acs-init-credentials}"

if ! oc whoami &>/dev/null; then
  echo "ERROR: log in to hub (export KUBECONFIG=/tmp/hub-kubeconfig)" >&2
  exit 1
fi

echo "== ACS init bundle sync =="

if [[ -n "${ROX_ADMIN_PASSWORD:-}" ]]; then
  oc create secret generic "${SECRET}" -n "${NS}" \
    --from-literal=ROX_ADMIN_PASSWORD="${ROX_ADMIN_PASSWORD}" \
    --dry-run=client -o yaml | oc apply -f -
  echo "Applied Secret ${SECRET} from ROX_ADMIN_PASSWORD env."
elif oc get secret "${SECRET}" -n "${NS}" &>/dev/null; then
  echo "Using existing Secret ${SECRET}."
else
  echo "ERROR: export ROX_ADMIN_PASSWORD or create Secret ${SECRET} in ${NS}" >&2
  echo "  oc create secret generic ${SECRET} -n ${NS} --from-literal=ROX_ADMIN_PASSWORD='...'" >&2
  exit 1
fi

HUB_DOMAIN="${HUB_DOMAIN:-$(oc get ingresses.config cluster -o jsonpath='{.spec.domain}' 2>/dev/null || true)}"
if [[ -n "${HUB_DOMAIN}" ]]; then
  echo "Waiting for Central route https://central-stackrox.${HUB_DOMAIN}/ ..."
  for attempt in $(seq 1 30); do
    code=$(curl -skI -o /dev/null -w '%{http_code}' --connect-timeout 10 \
      "https://central-stackrox.${HUB_DOMAIN}/" 2>/dev/null || echo "000")
    echo "  attempt ${attempt}/30 HTTP ${code}"
    if [[ "${code}" =~ ^(200|302|303)$ ]]; then
      break
    fi
    sleep 20
  done
fi

echo "Re-triggering acs-init-bundle-sync PostSync Job..."
oc delete job acs-init-bundle-sync-hook -n "${NS}" --ignore-not-found
for app in acs-init-bundle-sync field-content-acs-init-bundle-sync; do
  if oc get application "${app}" -n openshift-gitops &>/dev/null; then
    oc annotate application "${app}" -n openshift-gitops \
      argocd.argoproj.io/refresh=hard --overwrite
    echo "Refreshed Argo application ${app}."
    break
  fi
done

echo ""
echo "Watch progress:"
echo "  oc logs -n ${NS} job/acs-init-bundle-sync-hook -f"
echo "  oc get securedcluster -n ${NS}"
echo "  curl -skI https://central-stackrox.${HUB_DOMAIN}/main/clusters"
echo "OK: ACS init bundle sync triggered."
