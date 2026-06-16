#!/usr/bin/env bash
# Day-2 helper: wait for GitLab Operator CR and re-trigger workshop bootstrap if needed.
# PostSync jobs in charts/all/gitlab-operator usually suffice on fresh install.
#
# Usage:
#   bash scripts/apply-gitlab-bootstrap.sh
set -euo pipefail

if ! oc whoami &>/dev/null; then
  echo "ERROR: log in to hub (export KUBECONFIG=/tmp/hub-kubeconfig)" >&2
  exit 1
fi

HUB_DOMAIN="${HUB_DOMAIN:-$(oc get ingresses.config cluster -o jsonpath='{.spec.domain}' 2>/dev/null || true)}"
GITLAB_URL="https://gitlab.apps.${HUB_DOMAIN}"
NS="${GITLAB_NS:-gitlab}"

echo "== GitLab bootstrap check (${GITLAB_URL}) =="

echo "-- GitLab CR"
oc get gitlab -n "$NS" 2>/dev/null || { echo "WARN: no GitLab CR in ${NS}" >&2; exit 0; }

echo "-- InstallPlans (approve Manual subscriptions if Pending)"
oc get installplan -n "$NS" -o custom-columns=NAME:.metadata.name,APPROVED:.spec.approved,PHASE:.status.phase 2>/dev/null || true
oc get installplan -n gitlab-runner -o custom-columns=NAME:.metadata.name,APPROVED:.spec.approved,PHASE:.status.phase 2>/dev/null || true

echo "-- Waiting for GitLab route..."
for attempt in $(seq 1 30); do
  code=$(curl -skI -o /dev/null -w '%{http_code}' --connect-timeout 10 "${GITLAB_URL}/" 2>/dev/null || echo 000)
  echo "  attempt ${attempt}/30 HTTP ${code}"
  if [[ "$code" =~ ^(200|302|303)$ ]]; then break; fi
  sleep 20
done

echo "-- PostSync jobs"
oc get job -n "$NS" gitlab-workshop-bootstrap 2>/dev/null || true
oc get job -n developer-hub gitlab-token-setup 2>/dev/null || true

if ! oc get job gitlab-workshop-bootstrap -n "$NS" -o jsonpath='{.status.succeeded}' 2>/dev/null | grep -q 1; then
  echo "Re-running gitlab-workshop-bootstrap (delete job to allow PostSync recreation)..."
  oc delete job gitlab-workshop-bootstrap -n "$NS" --ignore-not-found
  oc annotate application gitlab-operator -n openshift-gitops argocd.argoproj.io/refresh=hard --overwrite 2>/dev/null || true
fi

echo "OK: GitLab bootstrap check complete — verify groups at ${GITLAB_URL}/explore/groups"
