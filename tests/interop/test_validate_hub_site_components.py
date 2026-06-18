"""
Hub site component validation — Hybrid Mesh Platform.

Validates cluster connectivity, pod health, ArgoCD application status,
and storage classes on the hub cluster.
"""
import logging
import os

import pytest
from ocp_resources.storage_class import StorageClass
from validatedpatterns_tests.interop import application, components

from . import __loggername__

logger = logging.getLogger(__loggername__)


@pytest.mark.test_validate_hub_site_components
def test_validate_hub_site_components(openshift_dyn_client):
    """Dump hub cluster info (version, PVCs, storage classes)."""
    logger.info("Checking OpenShift version on hub")
    version_out = components.dump_openshift_version()
    logger.info(f"OpenShift version:\n{version_out}")

    logger.info("Dump PVC and StorageClass info")
    pvcs_out = components.dump_pvc()
    logger.info(f"PVCs:\n{pvcs_out}")

    for sc in StorageClass.get(dyn_client=openshift_dyn_client):
        logger.info(sc.instance)


@pytest.mark.validate_hub_site_reachable
def test_validate_hub_site_reachable(kube_config, openshift_dyn_client):
    """Verify hub API endpoint is reachable."""
    logger.info("Check hub site API endpoint is reachable")
    err_msg = components.validate_site_reachable(kube_config, openshift_dyn_client)
    if err_msg:
        logger.error(f"FAIL: {err_msg}")
        assert False, err_msg
    else:
        logger.info("PASS: Hub site is reachable")


@pytest.mark.check_pod_status_hub
def test_check_pod_status_hub(openshift_dyn_client):
    """Verify pods are running in all critical hub namespaces."""
    logger.info("Checking pod status in hub namespaces")
    projects = [
        # GitOps & fleet
        "openshift-gitops",
        "open-cluster-management",
        "open-cluster-management-hub",
        # Security
        "stackrox",
        # Mesh
        "istio-system",
        "redhat-connectivity-link-operator",
        # Observability
        "openshift-cluster-observability-operator",
        # Developer Hub
        "developer-hub",
        # Vault
        "vault",
        # Kairos
        "kairos-system",
        # Skupper
        "service-interconnect",
    ]
    err_msg = components.check_pod_status(openshift_dyn_client, projects)
    if err_msg:
        logger.error(f"FAIL: {err_msg}")
        assert False, err_msg
    else:
        logger.info("PASS: Pod status check succeeded for all hub namespaces.")


@pytest.mark.check_pod_status_gitlab
def test_check_pod_status_gitlab(openshift_dyn_client):
    """Verify GitLab pods are running."""
    logger.info("Checking GitLab pod status")
    err_msg = components.check_pod_status(openshift_dyn_client, ["gitlab"])
    if err_msg:
        logger.error(f"FAIL: GitLab pods unhealthy: {err_msg}")
        assert False, err_msg
    else:
        logger.info("PASS: GitLab pods are healthy.")


@pytest.mark.validate_acm_managed_clusters_hub
def test_validate_acm_managed_clusters_hub(openshift_dyn_client):
    """Verify east and west spoke clusters are registered in ACM."""
    if os.getenv("PATTERN_SHORTNAME", "") == "standalone":
        pytest.skip("Standalone configuration — skipping ACM spoke checks.")

    logger.info("Checking ACM managed clusters (east + west)")
    kubefiles = []
    for env_var in ["KUBECONFIG_EDGE", "KUBECONFIG_WEST"]:
        kf = os.getenv(env_var)
        if kf:
            kubefiles.append(kf)

    if not kubefiles:
        pytest.skip("No KUBECONFIG_EDGE or KUBECONFIG_WEST set — skipping spoke check.")

    err_msg = components.validate_acm_self_registration_managed_clusters(
        openshift_dyn_client, kubefiles
    )
    if err_msg:
        logger.error(f"FAIL: {err_msg}")
        assert False, err_msg
    else:
        logger.info("PASS: Spoke clusters are registered in ACM.")


@pytest.mark.validate_argocd_reachable_hub_site
def test_validate_argocd_reachable_hub_site(openshift_dyn_client):
    """Verify Argo CD is reachable on hub."""
    logger.info("Check Argo CD route on hub is reachable")
    err_msg = components.validate_argocd_reachable(openshift_dyn_client)
    if err_msg:
        logger.error(f"FAIL: {err_msg}")
        assert False, err_msg
    else:
        logger.info("PASS: Argo CD is reachable.")


@pytest.mark.validate_argocd_applications_health_hub_site
def test_validate_argocd_applications_health_hub_site(openshift_dyn_client):
    """Verify all Argo CD applications on hub are Healthy (or Progressing)."""
    logger.info("Checking ArgoCD application health on hub")
    # hybrid-mesh-platform uses openshift-gitops namespace (not vp-gitops)
    projects = ["openshift-gitops"]
    unhealthy_apps = application.get_argocd_application_status(
        openshift_dyn_client, projects
    )
    # Filter out known-Progressing apps (long-running deployments)
    progressing_allowed = {
        "openshift-ai-hub",   # InferenceService model loading
        "workshop-demos",     # Camel integration startup
    }
    real_unhealthy = {
        app: status
        for app, status in (unhealthy_apps or {}).items()
        if app not in progressing_allowed
    }
    if real_unhealthy:
        err_msg = "Some ArgoCD applications on hub are unhealthy"
        logger.error(f"FAIL: {err_msg}:\n{real_unhealthy}")
        assert False, err_msg
    else:
        logger.info("PASS: All hub ArgoCD applications are healthy.")
