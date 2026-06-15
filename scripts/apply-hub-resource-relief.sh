#!/usr/bin/env bash
# Free hub CPU/memory for ACS Central + Gitea on constrained RHDP fleets.
# Idempotent — safe to re-run after Argo sync or notebook scale-up.
set -euo pipefail

echo "== Hub resource relief (ACS / Gitea priority) =="

if ! oc whoami &>/dev/null; then
  echo "ERROR: log in to hub (export KUBECONFIG=/tmp/hub-kubeconfig)" >&2
  exit 1
fi

echo "-- MaaS workshop predictors → 0"
for isvc in $(oc get isvc -n maas-workshop -o name 2>/dev/null || true); do
  oc patch "$isvc" -n maas-workshop --type merge \
    -p '{"spec":{"predictor":{"minReplicas":0,"maxReplicas":0}}}' 2>/dev/null || true
done
oc scale deploy --replicas=0 -n maas-workshop --all 2>/dev/null || true

echo "-- OpenShift AI per-user notebooks → 0"
for ns in $(oc get ns -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | grep '^ai-user' || true); do
  oc scale statefulset neuroface-ml-lab -n "$ns" --replicas=0 2>/dev/null || true
done

echo "-- RHODS operator + dashboard → 1 replica"
oc scale deploy rhods-operator -n redhat-ods-operator --replicas=1 2>/dev/null || true
oc scale deploy rhods-dashboard -n redhat-ods-applications --replicas=1 2>/dev/null || true

echo "-- ACS scanner duplicates → 1"
oc scale deploy scanner-v4-indexer scanner-v4-matcher -n stackrox --replicas=1 2>/dev/null || true

echo "-- NeuroFace YOLO serving → 0 (restore after verify if needed)"
oc scale deploy yolo-ppe-serving -n neuroface --replicas=0 2>/dev/null || true

echo "-- Pending noobaa backing-store pods (optional)"
oc delete pod -n openshift-storage -l noobaa-operator=noobaa --field-selector=status.phase=Pending \
  --force --grace-period=0 2>/dev/null || true
oc get pods -n openshift-storage 2>/dev/null | awk '/backing-store/ {print $1}' | \
  xargs -r oc delete pod -n openshift-storage --force --grace-period=0 2>/dev/null || true
oc scale deploy noobaa-endpoint noobaa-core -n openshift-storage --replicas=0 2>/dev/null || true

echo "-- ACS stackrox scanners → 0 until Central DB schedules (operator will restore on sync)"
oc scale deploy scanner-v4-indexer scanner-v4-matcher scanner-v4-db scanner config-controller \
  -n stackrox --replicas=0 2>/dev/null || true

echo "OK: hub resource relief applied — wait 60–120s for scheduler, then check:"
echo "  oc get pods -n stackrox | grep central"
echo "  curl -skI https://central-stackrox.\$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}')/"
