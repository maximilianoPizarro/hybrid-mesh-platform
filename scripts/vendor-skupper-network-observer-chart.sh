#!/usr/bin/env bash
# Vendor Skupper network-observer OCI subchart for offline helm lint / Argo sync.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHART_DIR="${ROOT}/charts/all/skupper-network-observer"
VERSION="${1:-2.1.3}"

mkdir -p "${CHART_DIR}/charts"
helm pull "oci://quay.io/skupper/helm/network-observer" \
  --version "${VERSION}" \
  -d "${CHART_DIR}/charts"

echo "Vendored network-observer-${VERSION}.tgz under ${CHART_DIR}/charts/"
echo "Commit Chart.lock, Chart.yaml (if version changed), and charts/*.tgz"
