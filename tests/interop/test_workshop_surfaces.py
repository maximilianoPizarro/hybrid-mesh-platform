"""
Workshop surface HTTP 200 tests — Hybrid Mesh Platform.

Validates that all platform console links and workshop URLs return expected
HTTP status codes. Mirrors scripts/verify-workshop-http200.sh using pytest.
"""
import logging
import os

import pytest
import requests

from . import __loggername__

logger = logging.getLogger(__loggername__)

# Disable SSL warnings for self-signed OpenShift certs
requests.packages.urllib3.disable_warnings()  # type: ignore[attr-defined]

# Hub domain injected via environment (from oc get ingresses.config)
HUB_DOMAIN = os.environ.get("HUB_APPS_DOMAIN", "")
EAST_DOMAIN = os.environ.get("EAST_APPS_DOMAIN", "")
WEST_DOMAIN = os.environ.get("WEST_APPS_DOMAIN", "")
TIMEOUT = int(os.environ.get("HTTP_CHECK_TIMEOUT", "15"))


def _check_url(url: str, expected_codes: tuple = (200, 301, 302)) -> str | None:
    """Return None on success, error string on failure."""
    try:
        r = requests.get(url, timeout=TIMEOUT, verify=False, allow_redirects=True)
        if r.status_code in expected_codes:
            return None
        return f"HTTP {r.status_code} (expected one of {expected_codes})"
    except requests.RequestException as exc:
        return str(exc)


def _skip_if_no_hub():
    if not HUB_DOMAIN:
        pytest.skip("HUB_APPS_DOMAIN not set — skipping HTTP surface checks.")


# ── Hub console surfaces ────────────────────────────────────────────────────

@pytest.mark.workshop_surface_argo
def test_surface_argocd():
    """ArgoCD console is reachable on hub."""
    _skip_if_no_hub()
    url = f"https://openshift-gitops-server-openshift-gitops.{HUB_DOMAIN}"
    err = _check_url(url)
    assert not err, f"ArgoCD unreachable at {url}: {err}"
    logger.info(f"PASS: ArgoCD {url}")


@pytest.mark.workshop_surface_developer_hub
def test_surface_developer_hub():
    """Developer Hub is reachable and returns 200."""
    _skip_if_no_hub()
    url = f"https://developer-hub.{HUB_DOMAIN}"
    err = _check_url(url, expected_codes=(200,))
    assert not err, f"Developer Hub unreachable at {url}: {err}"
    logger.info(f"PASS: Developer Hub {url}")


@pytest.mark.workshop_surface_developer_hub_create
def test_surface_developer_hub_create():
    """Developer Hub /create (software templates) is accessible."""
    _skip_if_no_hub()
    url = f"https://developer-hub.{HUB_DOMAIN}/create"
    err = _check_url(url, expected_codes=(200,))
    assert not err, f"DH /create unreachable at {url}: {err}"
    logger.info(f"PASS: Developer Hub /create {url}")


@pytest.mark.workshop_surface_gitlab
def test_surface_gitlab():
    """GitLab SCM is reachable (redirect to HTTPS login)."""
    _skip_if_no_hub()
    url = f"https://gitlab.apps.{HUB_DOMAIN}"
    err = _check_url(url, expected_codes=(200, 302))
    assert not err, f"GitLab unreachable at {url}: {err}"
    logger.info(f"PASS: GitLab {url}")


@pytest.mark.workshop_surface_grafana
def test_surface_grafana():
    """Grafana dashboards are reachable."""
    _skip_if_no_hub()
    url = f"https://grafana.{HUB_DOMAIN}"
    err = _check_url(url)
    assert not err, f"Grafana unreachable at {url}: {err}"
    logger.info(f"PASS: Grafana {url}")


@pytest.mark.workshop_surface_kafka_console
def test_surface_kafka_console():
    """Kafka Console UI is reachable."""
    _skip_if_no_hub()
    url = f"https://kafka-console.{HUB_DOMAIN}"
    err = _check_url(url)
    assert not err, f"Kafka Console unreachable at {url}: {err}"
    logger.info(f"PASS: Kafka Console {url}")


@pytest.mark.workshop_surface_neuroface
def test_surface_neuroface():
    """NeuroFace AI app is reachable."""
    _skip_if_no_hub()
    url = f"https://neuroface.{HUB_DOMAIN}"
    err = _check_url(url)
    assert not err, f"NeuroFace unreachable at {url}: {err}"
    logger.info(f"PASS: NeuroFace {url}")


@pytest.mark.workshop_surface_industrial_edge
def test_surface_industrial_edge():
    """Industrial Edge hub gateway route is reachable."""
    _skip_if_no_hub()
    url = f"https://industrial-edge.{HUB_DOMAIN}"
    err = _check_url(url)
    assert not err, f"Industrial Edge hub GW unreachable at {url}: {err}"
    logger.info(f"PASS: Industrial Edge {url}")


@pytest.mark.workshop_surface_skupper
def test_surface_skupper_observer():
    """Skupper Network Observer is reachable."""
    _skip_if_no_hub()
    url = f"https://skupper-network-observer-service-interconnect.{HUB_DOMAIN}"
    err = _check_url(url)
    assert not err, f"Skupper observer unreachable at {url}: {err}"
    logger.info(f"PASS: Skupper observer {url}")


@pytest.mark.workshop_surface_quay
def test_surface_quay_registry():
    """Quay registry is reachable."""
    _skip_if_no_hub()
    url = f"https://quay-registry.{HUB_DOMAIN}"
    err = _check_url(url)
    assert not err, f"Quay registry unreachable at {url}: {err}"
    logger.info(f"PASS: Quay {url}")


@pytest.mark.workshop_surface_vault
def test_surface_vault():
    """Vault UI is reachable at /ui/."""
    _skip_if_no_hub()
    url = f"https://vault-vault.{HUB_DOMAIN}/ui/"
    err = _check_url(url)
    assert not err, f"Vault unreachable at {url}: {err}"
    logger.info(f"PASS: Vault /ui/ {url}")


@pytest.mark.workshop_surface_showroom
def test_surface_showroom():
    """Showroom workshop portal is reachable."""
    _skip_if_no_hub()
    url = f"https://showroom-showroom.{HUB_DOMAIN}/"
    err = _check_url(url)
    assert not err, f"Showroom unreachable at {url}: {err}"
    logger.info(f"PASS: Showroom {url}")


@pytest.mark.workshop_surface_mcp
def test_surface_mcp_gateway():
    """MCP Gateway is reachable."""
    _skip_if_no_hub()
    url = f"https://mcp-gateway.{HUB_DOMAIN}/mcp"
    err = _check_url(url, expected_codes=(200, 405, 400))
    assert not err, f"MCP Gateway unreachable at {url}: {err}"
    logger.info(f"PASS: MCP Gateway {url}")


# ── Kuadrant / AI Gateway (401 = protected, expected) ──────────────────────

@pytest.mark.workshop_surface_kuadrant
def test_surface_workshop_apis_kuadrant():
    """Workshop APIs gateway returns 401 (Kuadrant protected — no API key)."""
    _skip_if_no_hub()
    url = f"https://workshop-apis.{HUB_DOMAIN}/httpbin/get"
    err = _check_url(url, expected_codes=(401,))
    assert not err, f"Workshop APIs not Kuadrant-protected at {url}: {err}"
    logger.info(f"PASS: Workshop APIs Kuadrant-protected (401) {url}")


@pytest.mark.workshop_surface_ai_gateway
def test_surface_ai_gateway_kuadrant():
    """AI Gateway chat completions returns 401 (Kuadrant protected — no API key)."""
    _skip_if_no_hub()
    url = f"https://ai-gateway.{HUB_DOMAIN}/v1/chat/completions"
    err = _check_url(url, expected_codes=(401,))
    assert not err, f"AI Gateway not Kuadrant-protected at {url}: {err}"
    logger.info(f"PASS: AI Gateway Kuadrant-protected (401) {url}")


# ── Spoke surfaces ──────────────────────────────────────────────────────────

@pytest.mark.workshop_surface_east_devspaces
def test_surface_east_devspaces():
    """DevSpaces on east spoke is reachable."""
    if not EAST_DOMAIN:
        pytest.skip("EAST_APPS_DOMAIN not set — skipping east spoke check.")
    url = f"https://devspaces.{EAST_DOMAIN}/"
    err = _check_url(url)
    assert not err, f"East DevSpaces unreachable at {url}: {err}"
    logger.info(f"PASS: East DevSpaces {url}")


@pytest.mark.workshop_surface_east_line_dashboard
def test_surface_east_line_dashboard():
    """Industrial Edge Line Dashboard on east spoke is reachable."""
    if not EAST_DOMAIN:
        pytest.skip("EAST_APPS_DOMAIN not set — skipping east spoke check.")
    url = f"https://line-dashboard-industrial-edge-tst-all.{EAST_DOMAIN}/"
    err = _check_url(url)
    assert not err, f"East Line Dashboard unreachable at {url}: {err}"
    logger.info(f"PASS: East Line Dashboard {url}")
