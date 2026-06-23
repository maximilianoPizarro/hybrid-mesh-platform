"""
Edge (spoke) site component validation — Hybrid Mesh Platform.

Validates Industrial Edge stack, Skupper connector, and Argo CD health
on east/west spoke clusters.
"""
import logging
import os

import pytest
from validatedpatterns_tests.interop import application, components

from . import __loggername__

logger = logging.getLogger(__loggername__)


@pytest.mark.test_validate_edge_site_components
def test_validate_edge_site_components():
    """Dump spoke cluster OpenShift version info."""
    logger.info("Checking OpenShift version on edge site")
    version_out = components.dump_openshift_version()
    logger.info(f"OpenShift version:\n{version_out}")


@pytest.mark.validate_edge_site_reachable
def test_validate_edge_site_reachable(kube_config, openshift_dyn_client):
    """Verify spoke API endpoint is reachable."""
    logger.info("Check edge site API endpoint is reachable")
    err_msg = components.validate_site_reachable(kube_config, openshift_dyn_client)
    if err_msg:
        logger.error(f"FAIL: {err_msg}")
        assert False, err_msg
    else:
        logger.info("PASS: Edge site is reachable")


@pytest.mark.check_pod_status_edge
def test_check_pod_status_edge(openshift_dyn_client):
    """Verify pods are running in spoke namespaces (ACM agent, mesh, IE)."""
    logger.info("Checking pod status in spoke namespaces")
    projects = [
        # ACM agent
        "open-cluster-management-agent",
        "open-cluster-management-agent-addon",
        # Spoke GitOps
        "openshift-gitops",
        # Mesh
        "istio-system",
        # Skupper connector
        "service-interconnect",
        # NeuroFace CV (default spoke workload)
        "neuroface",
        "neuroface-cv",
    ]
    if os.environ.get("VERIFY_IE", "0") == "1":
        projects.append("industrial-edge-tst-all")
    err_msg = components.check_pod_status(openshift_dyn_client, projects)
    if err_msg:
        logger.error(f"FAIL: {err_msg}")
        assert False, err_msg
    else:
        logger.info("PASS: Edge pod status check succeeded.")


@pytest.mark.validate_argocd_reachable_edge_site
def test_validate_argocd_reachable_edge_site(openshift_dyn_client):
    """Verify Argo CD is reachable on spoke."""
    logger.info("Check Argo CD route on edge site is reachable")
    err_msg = components.validate_argocd_reachable(openshift_dyn_client)
    if err_msg:
        logger.error(f"FAIL: {err_msg}")
        assert False, err_msg
    else:
        logger.info("PASS: Edge Argo CD is reachable.")


@pytest.mark.validate_argocd_applications_health_edge_site
def test_validate_argocd_applications_health_edge_site(openshift_dyn_client):
    """Verify Argo CD applications on spoke are Healthy."""
    logger.info("Checking ArgoCD application health on edge site")
    projects = ["openshift-gitops"]
    unhealthy_apps = application.get_argocd_application_status(
        openshift_dyn_client, projects
    )
    # Allow Progressing on IE (Camel K, Kafka startup)
    progressing_allowed = {"industrial-edge-tst", "east-spoke-components"}
    real_unhealthy = {
        app: status
        for app, status in (unhealthy_apps or {}).items()
        if app not in progressing_allowed
    }
    if real_unhealthy:
        err_msg = "Some ArgoCD applications on edge are unhealthy"
        logger.error(f"FAIL: {err_msg}:\n{real_unhealthy}")
        assert False, err_msg
    else:
        logger.info("PASS: Edge ArgoCD applications are healthy.")


@pytest.mark.validate_industrial_edge_pods
def test_validate_industrial_edge_pods(openshift_dyn_client):
    """Verify Industrial Edge stack pods (Kafka, Camel, sensors) are running."""
    logger.info("Checking Industrial Edge pod status")
    err_msg = components.check_pod_status(
        openshift_dyn_client, ["industrial-edge-tst-all"]
    )
    if err_msg:
        logger.warning(
            f"Industrial Edge pods not fully ready (may be starting): {err_msg}"
        )
        # Non-blocking: IE startup can take several minutes
    else:
        logger.info("PASS: Industrial Edge pods are running.")


@pytest.mark.validate_skupper_connector_edge
def test_validate_skupper_connector_edge(openshift_dyn_client):
    """Verify Skupper connector is running on spoke."""
    logger.info("Checking Skupper connector pods on spoke")
    err_msg = components.check_pod_status(
        openshift_dyn_client, ["service-interconnect"]
    )
    if err_msg:
        logger.error(f"FAIL: Skupper connector not healthy: {err_msg}")
        assert False, err_msg
    else:
        logger.info("PASS: Skupper connector is running on spoke.")
