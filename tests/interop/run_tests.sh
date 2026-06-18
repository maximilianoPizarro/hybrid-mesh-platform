#!/usr/bin/env bash
# Hybrid Mesh Platform — VP-style interop test runner.
# Invoked by: make qe-tests (from common/Makefile) or directly.
#
# Required env:
#   KUBECONFIG          — hub cluster kubeconfig
#   KUBECONFIG_EDGE     — east spoke kubeconfig (optional for spoke tests)
#   KUBECONFIG_WEST     — west spoke kubeconfig (optional)
#   INFRA_PROVIDER      — cloud/infra description (AWS, RHDP, etc.)
#
# Optional env:
#   HUB_APPS_DOMAIN     — hub apps domain (e.g. apps.cluster-xxx.redhatworkshops.io)
#   EAST_APPS_DOMAIN    — east spoke apps domain
#   WEST_APPS_DOMAIN    — west spoke apps domain
#   WORKSPACE           — dir for JUnit XML results (default: /tmp/vp-qe-results)
#   SKUPPER_VAN_SITES   — expected Skupper VAN site count (default: 3)
#   CONTENT_UPDATE_TIMEOUT_MINUTES — GitOps roundtrip timeout (default: 10)
set -euo pipefail

export EXTERNAL_TEST="true"
export PATTERN_NAME="HybridMeshPlatform"
export PATTERN_SHORTNAME="hybrid-mesh"

# ── Validate required inputs ────────────────────────────────────────────────

if [ -z "${KUBECONFIG:-}" ]; then
    echo "ERROR: KUBECONFIG is not set (hub kubeconfig required)"
    exit 1
fi

if [ -z "${INFRA_PROVIDER:-}" ]; then
    echo "ERROR: INFRA_PROVIDER is not set (e.g. RHDP, AWS, GCP)"
    exit 1
fi

if [ -z "${WORKSPACE:-}" ]; then
    WORKSPACE=$(mktemp -d -t vp-qe-results-XXXXXX)
    export WORKSPACE
    echo "INFO: WORKSPACE not set, using ${WORKSPACE}"
fi

mkdir -p "${WORKSPACE}"

# ── Derive hub domain from cluster if not set ────────────────────────────────

if [ -z "${HUB_APPS_DOMAIN:-}" ]; then
    HUB_APPS_DOMAIN=$(oc get ingresses.config cluster \
        -o jsonpath='{.spec.domain}' 2>/dev/null || true)
    export HUB_APPS_DOMAIN
    echo "INFO: HUB_APPS_DOMAIN resolved to ${HUB_APPS_DOMAIN}"
fi

if [ -n "${KUBECONFIG_EDGE:-}" ] && [ -z "${EAST_APPS_DOMAIN:-}" ]; then
    EAST_APPS_DOMAIN=$(KUBECONFIG="${KUBECONFIG_EDGE}" oc get ingresses.config cluster \
        -o jsonpath='{.spec.domain}' 2>/dev/null || true)
    export EAST_APPS_DOMAIN
    echo "INFO: EAST_APPS_DOMAIN resolved to ${EAST_APPS_DOMAIN}"
fi

if [ -n "${KUBECONFIG_WEST:-}" ] && [ -z "${WEST_APPS_DOMAIN:-}" ]; then
    WEST_APPS_DOMAIN=$(KUBECONFIG="${KUBECONFIG_WEST}" oc get ingresses.config cluster \
        -o jsonpath='{.spec.domain}' 2>/dev/null || true)
    export WEST_APPS_DOMAIN
    echo "INFO: WEST_APPS_DOMAIN resolved to ${WEST_APPS_DOMAIN}"
fi

echo ""
echo "========================================================"
echo " Hybrid Mesh Platform — VP Interop Test Suite"
echo " Hub:        ${KUBECONFIG}"
echo " Hub domain: ${HUB_APPS_DOMAIN:-<not set>}"
echo " East spoke: ${KUBECONFIG_EDGE:-<not set>}"
echo " West spoke: ${KUBECONFIG_WEST:-<not set>}"
echo " Results:    ${WORKSPACE}"
echo " Provider:   ${INFRA_PROVIDER}"
echo "========================================================"
echo ""

PYTEST_OPTS="-lv --disable-warnings --tb=short"

# ── Hub tests ───────────────────────────────────────────────────────────────

echo ">>> [1/6] Hub subscription status"
pytest ${PYTEST_OPTS} \
    test_subscription_status_hub.py \
    --kubeconfig "${KUBECONFIG}" \
    --junit-xml "${WORKSPACE}/test_subscription_status_hub.xml" || true

echo ">>> [2/6] Hub site component validation"
pytest ${PYTEST_OPTS} \
    test_validate_hub_site_components.py \
    --kubeconfig "${KUBECONFIG}" \
    --junit-xml "${WORKSPACE}/test_validate_hub_site_components.xml" || true

echo ">>> [3/6] Platform-specific components (Skupper, GitLab GW, Kairos, Kuadrant, ACM)"
pytest ${PYTEST_OPTS} \
    test_platform_components.py \
    --kubeconfig "${KUBECONFIG}" \
    --junit-xml "${WORKSPACE}/test_platform_components.xml" || true

echo ">>> [4/6] Workshop HTTP surfaces (console links + Kuadrant 401)"
pytest ${PYTEST_OPTS} \
    test_workshop_surfaces.py \
    --kubeconfig "${KUBECONFIG}" \
    --junit-xml "${WORKSPACE}/test_workshop_surfaces.xml" || true

# ── Spoke (east) tests ───────────────────────────────────────────────────────

if [ -n "${KUBECONFIG_EDGE:-}" ]; then
    echo ">>> [5/6] East spoke subscription status"
    pytest ${PYTEST_OPTS} \
        test_subscription_status_edge.py \
        --kubeconfig "${KUBECONFIG_EDGE}" \
        --junit-xml "${WORKSPACE}/test_subscription_status_edge.xml" || true

    echo ">>> [5b/6] East spoke site components (IE, Skupper, Argo CD)"
    pytest ${PYTEST_OPTS} \
        test_validate_edge_site_components.py \
        --kubeconfig "${KUBECONFIG_EDGE}" \
        --junit-xml "${WORKSPACE}/test_validate_edge_site_components.xml" || true
else
    echo ">>> [5/6] Skipping edge spoke tests (KUBECONFIG_EDGE not set)"
fi

# ── E2E GitOps roundtrip (optional — only when PATTERNS_REPO_PATH is set) ───

if [ -n "${PATTERNS_REPO_PATH:-}" ]; then
    echo ">>> [6/6] GitOps roundtrip — showroom content update"
    pytest ${PYTEST_OPTS} \
        test_modify_web_content.py \
        --kubeconfig "${KUBECONFIG}" \
        --junit-xml "${WORKSPACE}/test_modify_web_content.xml" || true
else
    echo ">>> [6/6] Skipping GitOps roundtrip (PATTERNS_REPO_PATH not set)"
fi

# ── Badge + summary ─────────────────────────────────────────────────────────

echo ""
echo ">>> Generating CI badge"
python3 create_ci_badge.py || true

echo ""
echo "========================================================"
echo " Test results written to: ${WORKSPACE}"
ls "${WORKSPACE}"/*.xml 2>/dev/null | head -10 || true
echo "========================================================"
