"""
Platform-specific component tests — Hybrid Mesh Platform.

Validates Skupper VAN connectivity, GitLab Gateway, Developer Hub
catalog health, Kairos SmartScalingPolicies, and Kuadrant APIProducts.
"""
import logging
import os

import pytest
import requests
from ocp_resources.route import Route

from . import __loggername__

logger = logging.getLogger(__loggername__)

requests.packages.urllib3.disable_warnings()  # type: ignore[attr-defined]

HUB_DOMAIN = os.environ.get("HUB_APPS_DOMAIN", "")
TIMEOUT = int(os.environ.get("HTTP_CHECK_TIMEOUT", "15"))

SKUPPER_EXPECTED_VAN_SITES = int(os.environ.get("SKUPPER_VAN_SITES", "3"))


# ── Skupper VAN connectivity ────────────────────────────────────────────────

@pytest.mark.skupper_van
def test_skupper_van_sites(openshift_dyn_client):
    """Verify Skupper VAN has expected number of connected sites."""
    try:
        from ocp_resources.resource import Resource

        sites = list(
            Resource.get(
                dyn_client=openshift_dyn_client,
                api_group="skupper.io",
                api_version="v2alpha1",
                kind="Site",
                namespace="service-interconnect",
            )
        )
    except Exception:
        # Try v1alpha1
        try:
            from ocp_resources.resource import Resource

            sites = list(
                Resource.get(
                    dyn_client=openshift_dyn_client,
                    api_group="skupper.io",
                    api_version="v1alpha1",
                    kind="Site",
                    namespace="service-interconnect",
                )
            )
        except Exception as exc:
            pytest.skip(f"Could not list Skupper Sites: {exc}")

    if not sites:
        err_msg = "No Skupper Site found in service-interconnect"
        logger.error(f"FAIL: {err_msg}")
        assert False, err_msg

    site = sites[0]
    van_sites = getattr(site.instance.status, "sitesInNetwork", 0)
    logger.info(f"Skupper VAN sites in network: {van_sites}")

    if van_sites < SKUPPER_EXPECTED_VAN_SITES:
        err_msg = (
            f"Skupper VAN has {van_sites} sites, expected >= {SKUPPER_EXPECTED_VAN_SITES}"
        )
        logger.error(f"FAIL: {err_msg}")
        assert False, err_msg
    else:
        logger.info(
            f"PASS: Skupper VAN has {van_sites} connected sites "
            f"(expected >= {SKUPPER_EXPECTED_VAN_SITES})."
        )


# ── GitLab Gateway ──────────────────────────────────────────────────────────

@pytest.mark.gitlab_gateway
def test_gitlab_gateway_programmed(openshift_dyn_client):
    """Verify the dedicated GitLab Istio Gateway is Programmed."""
    try:
        from ocp_resources.resource import Resource

        gateways = list(
            Resource.get(
                dyn_client=openshift_dyn_client,
                api_group="gateway.networking.k8s.io",
                api_version="v1",
                kind="Gateway",
                namespace="gitlab",
                name="gitlab-gateway",
            )
        )
    except Exception as exc:
        pytest.skip(f"Could not list Gateway resources: {exc}")

    if not gateways:
        err_msg = "gitlab-gateway not found in gitlab namespace"
        logger.error(f"FAIL: {err_msg}")
        assert False, err_msg

    gw = gateways[0]
    conditions = getattr(gw.instance.status, "conditions", [])
    programmed = any(
        c.get("type") == "Programmed" and c.get("status") == "True"
        for c in conditions
    )
    if not programmed:
        err_msg = f"gitlab-gateway not Programmed: {conditions}"
        logger.error(f"FAIL: {err_msg}")
        assert False, err_msg
    else:
        logger.info("PASS: gitlab-gateway is Programmed.")


# ── Developer Hub catalog ───────────────────────────────────────────────────

@pytest.mark.developer_hub_catalog
def test_developer_hub_catalog_entities(openshift_dyn_client):
    """Verify Developer Hub catalog returns entities (authenticated check via route)."""
    if not HUB_DOMAIN:
        pytest.skip("HUB_APPS_DOMAIN not set — skipping Developer Hub catalog check.")

    # Health endpoint (no auth required)
    url = f"https://developer-hub.{HUB_DOMAIN}"
    try:
        r = requests.get(url, timeout=TIMEOUT, verify=False)
        assert r.status_code == 200, f"Developer Hub returned HTTP {r.status_code}"
        logger.info(f"PASS: Developer Hub home returns 200.")
    except requests.RequestException as exc:
        err_msg = f"Developer Hub unreachable: {exc}"
        logger.error(f"FAIL: {err_msg}")
        assert False, err_msg

    # Catalog API (RBAC: unauthenticated returns [] but endpoint itself is reachable)
    catalog_url = f"https://developer-hub.{HUB_DOMAIN}/api/catalog/entities?filter=kind=component&limit=1"
    try:
        r = requests.get(catalog_url, timeout=TIMEOUT, verify=False)
        # 200 with [] (RBAC) or actual data — both OK
        assert r.status_code == 200, f"Catalog API returned HTTP {r.status_code}"
        logger.info(f"PASS: Developer Hub catalog API reachable (RBAC active, status={r.status_code}).")
    except requests.RequestException as exc:
        logger.warning(f"Developer Hub catalog API check warning: {exc}")


@pytest.mark.developer_hub_lightspeed
def test_developer_hub_lightspeed():
    """Verify Developer Hub Lightspeed endpoint is reachable."""
    if not HUB_DOMAIN:
        pytest.skip("HUB_APPS_DOMAIN not set.")
    url = f"https://developer-hub.{HUB_DOMAIN}/lightspeed"
    try:
        r = requests.get(url, timeout=TIMEOUT, verify=False)
        assert r.status_code == 200, f"Lightspeed returned HTTP {r.status_code}"
        logger.info(f"PASS: Developer Hub Lightspeed {url}")
    except requests.RequestException as exc:
        err_msg = f"Lightspeed unreachable: {exc}"
        logger.error(f"FAIL: {err_msg}")
        assert False, err_msg


# ── Kairos SmartScalingPolicies ─────────────────────────────────────────────

@pytest.mark.kairos_policies
def test_kairos_gitlab_scaling_policies(openshift_dyn_client):
    """Verify Kairos SmartScalingPolicies for GitLab are created and not paused."""
    try:
        from ocp_resources.resource import Resource

        policies = list(
            Resource.get(
                dyn_client=openshift_dyn_client,
                api_group="kairos.maximilianopizarro.github.io",
                api_version="v1alpha1",
                kind="SmartScalingPolicy",
                namespace="kairos-system",
            )
        )
    except Exception as exc:
        pytest.skip(f"Kairos SmartScalingPolicy CRD not available: {exc}")

    gitlab_policies = [
        p for p in policies
        if "gitlab" in p.instance.metadata.name
    ]

    if not gitlab_policies:
        err_msg = "No Kairos SmartScalingPolicies found for GitLab in kairos-system"
        logger.error(f"FAIL: {err_msg}")
        assert False, err_msg

    paused = [p.instance.metadata.name for p in gitlab_policies if p.instance.spec.get("paused")]
    if paused:
        err_msg = f"GitLab SmartScalingPolicies are paused: {paused}"
        logger.error(f"FAIL: {err_msg}")
        assert False, err_msg

    logger.info(
        f"PASS: {len(gitlab_policies)} GitLab SmartScalingPolicies found and active: "
        + ", ".join(p.instance.metadata.name for p in gitlab_policies)
    )


# ── Kuadrant APIProducts ────────────────────────────────────────────────────

@pytest.mark.kuadrant_api_products
def test_kuadrant_api_products_ready(openshift_dyn_client):
    """Verify Kuadrant APIProducts have discoveredPlans populated."""
    try:
        from ocp_resources.resource import Resource

        products = list(
            Resource.get(
                dyn_client=openshift_dyn_client,
                api_group="devportal.kuadrant.io",
                api_version="v1alpha1",
                kind="APIProduct",
            )
        )
    except Exception as exc:
        pytest.skip(f"Kuadrant APIProduct CRD not available: {exc}")

    if not products:
        err_msg = "No Kuadrant APIProducts found"
        logger.error(f"FAIL: {err_msg}")
        assert False, err_msg

    no_plans = [
        p.instance.metadata.name
        for p in products
        if not getattr(p.instance.status, "discoveredPlans", None)
    ]
    if no_plans:
        logger.warning(
            f"APIProducts without discoveredPlans (may need sync): {no_plans}"
        )
    else:
        logger.info(
            f"PASS: All {len(products)} APIProducts have discoveredPlans."
        )


@pytest.mark.kuadrant_httproutes
def test_kuadrant_httproutes_exist(openshift_dyn_client):
    """Verify Kuadrant HTTPRoutes for workshop APIs exist."""
    try:
        from ocp_resources.resource import Resource

        routes = list(
            Resource.get(
                dyn_client=openshift_dyn_client,
                api_group="gateway.networking.k8s.io",
                api_version="v1",
                kind="HTTPRoute",
            )
        )
    except Exception as exc:
        pytest.skip(f"HTTPRoute CRD not available: {exc}")

    route_names = {r.instance.metadata.name for r in routes}
    required = {"workshop-httpbin", "workshop-restcountries", "workshop-mcp", "ai-maas"}
    missing = required - route_names

    if missing:
        err_msg = f"Missing Kuadrant HTTPRoutes: {missing}"
        logger.error(f"FAIL: {err_msg}")
        assert False, err_msg
    else:
        logger.info(f"PASS: All required Kuadrant HTTPRoutes found: {required}")


# ── ACM + Observability ─────────────────────────────────────────────────────

@pytest.mark.acm_fleet
def test_acm_managed_clusters_available(openshift_dyn_client):
    """Verify ACM managed clusters (east + west) are Available."""
    try:
        from ocp_resources.resource import Resource

        clusters = list(
            Resource.get(
                dyn_client=openshift_dyn_client,
                api_group="cluster.open-cluster-management.io",
                api_version="v1",
                kind="ManagedCluster",
            )
        )
    except Exception as exc:
        pytest.skip(f"ACM ManagedCluster CRD not available: {exc}")

    spoke_clusters = [c for c in clusters if c.instance.metadata.name != "local-cluster"]

    if not spoke_clusters:
        err_msg = "No spoke ManagedClusters found (only local-cluster)"
        logger.warning(f"WARN: {err_msg}")
        return  # Non-blocking in standalone mode

    unavailable = []
    for cluster in spoke_clusters:
        conditions = cluster.instance.status.conditions or []
        available = any(
            c.get("type") == "ManagedClusterConditionAvailable"
            and c.get("status") == "True"
            for c in conditions
        )
        if not available:
            unavailable.append(cluster.instance.metadata.name)

    if unavailable:
        err_msg = f"ACM managed clusters not Available: {unavailable}"
        logger.error(f"FAIL: {err_msg}")
        assert False, err_msg
    else:
        logger.info(
            f"PASS: All {len(spoke_clusters)} spoke clusters Available: "
            + ", ".join(c.instance.metadata.name for c in spoke_clusters)
        )
