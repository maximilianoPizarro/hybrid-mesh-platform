"""
Hub operator subscription status — Hybrid Mesh Platform.

Validates that all required operator subscriptions are installed and
in AtleastOnceSucceeded / Succeeded phase on the hub cluster.
"""
import logging

import pytest
from validatedpatterns_tests.interop import subscription

from . import __loggername__

logger = logging.getLogger(__loggername__)


@pytest.mark.subscription_status_hub
def test_subscription_status_hub(openshift_dyn_client):
    """Verify all hub operator subscriptions are installed and healthy."""
    # Core platform operators with their namespaces
    expected_subs = {
        # GitOps / multi-cluster
        "openshift-gitops-operator": ["openshift-gitops-operator"],
        "advanced-cluster-management": ["open-cluster-management"],
        "multicluster-engine": ["multicluster-engine"],
        # Security
        "rhacs-operator": ["stackrox"],
        # Mesh + connectivity
        "servicemeshoperator3": ["openshift-operators"],
        "rhcl-operator": ["redhat-connectivity-link-operator"],
        # Skupper
        "skupper-operator": ["openshift-operators"],
        # GitLab SCM
        "gitlab-operator-kubernetes": ["gitlab"],
        # AI / data science
        "rhods-operator": ["redhat-ods-operator"],
        # Kairos AI operator
        "kairos-operator": ["kairos-system"],
        # External secrets
        "openshift-external-secrets-operator": ["external-secrets-operator"],
    }

    err_msg = subscription.subscription_status(
        openshift_dyn_client, expected_subs, diff=True
    )
    if err_msg:
        logger.error(f"FAIL: {err_msg}")
        assert False, err_msg
    else:
        logger.info("PASS: All hub subscriptions are healthy.")


@pytest.mark.subscription_status_hub_optional
def test_subscription_status_hub_optional(openshift_dyn_client):
    """Verify optional operator subscriptions (non-blocking)."""
    optional_subs = {
        # CNV / virtualization
        "kubevirt-hyperconverged": ["openshift-cnv"],
        # Cost management
        "costmanagement-metrics-operator": ["costmanagement-metrics-operator"],
    }

    err_msg = subscription.subscription_status(
        openshift_dyn_client, optional_subs, diff=False
    )
    if err_msg:
        logger.warning(
            f"Optional subscription check had warnings (non-blocking): {err_msg}"
        )
    else:
        logger.info("PASS: Optional hub subscriptions are healthy.")
