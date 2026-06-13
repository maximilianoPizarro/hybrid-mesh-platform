#!/usr/bin/env bash
# Vendor Camel Dashboard umbrella chart for spoke GitOps (offline-friendly).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHART_DIR="${ROOT}/charts/all/camel-dashboard-openshift"
VERSION="${1:-4.20.2}"

helm repo add camel-tooling https://camel-tooling.github.io/camel-dashboard/charts 2>/dev/null || true
helm repo update camel-tooling

mkdir -p "${CHART_DIR}/charts"
helm pull camel-tooling/camel-dashboard-openshift-all \
  --version "${VERSION}" \
  -d "${CHART_DIR}/charts"

echo "Vendored camel-dashboard-openshift-all-${VERSION}.tgz under ${CHART_DIR}/charts/"
echo "Commit Chart.lock, Chart.yaml (if version changed), and charts/*.tgz"
