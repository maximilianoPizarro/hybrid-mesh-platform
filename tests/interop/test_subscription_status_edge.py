"""
Spoke operator subscription status — Hybrid Mesh Platform.

Validates that all required operator subscriptions are present on
east/west spoke clusters. Run with KUBECONFIG_EDGE pointing to each spoke.
"""
import logging

import pytest
from validatedpatterns_tests.interop import subscription

from . import __loggername__

logger = logging.getLogger(__loggername__)


@pytest.mark.subscription_status_edge
def test_subscription_status_edge(openshift_dyn_client):
    """Verify spoke (edge) operator subscriptions are installed."""
    expected_subs = {
        # GitOps (spoke-local pull)
        "openshift-gitops-operator": ["openshift-gitops-operator"],
        # Mesh (spoke ambient mesh)
        "servicemeshoperator3": ["openshift-operators"],
        # Skupper connector
        "skupper-operator": ["openshift-operators"],
        # ACS secured cluster
        "rhacs-operator": ["stackrox"],
    }

    err_msg = subscription.subscription_status(
        openshift_dyn_client, expected_subs, diff=False
    )
    if err_msg:
        logger.error(f"FAIL: {err_msg}")
        assert False, err_msg
    else:
        logger.info("PASS: Spoke subscription status check passed.")


@pytest.mark.subscription_status_edge_optional
def test_subscription_status_edge_optional(openshift_dyn_client):
    """Verify optional spoke subscriptions (DevSpaces, CNV)."""
    optional_subs = {
        "devworkspace-operator": ["openshift-operators"],
        "web-terminal": ["openshift-operators"],
    }

    err_msg = subscription.subscription_status(
        openshift_dyn_client, optional_subs, diff=False
    )
    if err_msg:
        logger.warning(f"Optional spoke subscriptions warning (non-blocking): {err_msg}")
    else:
        logger.info("PASS: Optional spoke subscriptions are healthy.")
