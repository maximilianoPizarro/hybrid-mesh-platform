#!/usr/bin/env bash
# Fleet verification for Hybrid Mesh Platform (hub + ACM spokes)
set -euo pipefail

echo "=== Hybrid Mesh Platform verification ==="

echo "--- ManagedClusters ---"
oc get managedclusters 2>/dev/null || echo "WARN: not logged in or no ACM"

echo "--- Hub Argo CD applications (sample) ---"
oc get applications.argoproj.io -n openshift-gitops 2>/dev/null | head -20 || true

echo "--- RHCL operator ---"
oc get sub -n redhat-connectivity-link-operator 2>/dev/null || true

echo "--- IE namespace (east context if configured) ---"
oc get pods -n industrial-edge-tst-all 2>/dev/null | head -5 || echo "IE pods not on this cluster (expected on east spoke)"

echo "--- Skupper ---"
oc get skupperlinks -A 2>/dev/null | head -5 || true

echo "Done. See MIGRATION.md for full checklist."
