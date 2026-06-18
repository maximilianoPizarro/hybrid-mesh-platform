"""
GitOps E2E roundtrip test — Hybrid Mesh Platform.

Modifies the showroom userdata ConfigMap (workshop lab title), commits to Git,
and verifies the showroom pod picks up the change via Argo CD sync.

Equivalent to the VP multicloud-gitops hello-world content test, adapted for
the hybrid-mesh-platform showroom workshop surface.
"""
import logging
import os
import re
import subprocess
import time

import pytest
import requests
from ocp_resources.route import Route
from validatedpatterns_tests.interop.edge_util import modify_file_content

from . import __loggername__

logger = logging.getLogger(__loggername__)

CONTENT_UPDATE_TIMEOUT_MINUTES = int(
    os.environ.get("CONTENT_UPDATE_TIMEOUT_MINUTES", "10")
)
CONTENT_UPDATE_POLL_SECONDS = int(os.environ.get("CONTENT_UPDATE_POLL_SECONDS", "30"))

PATTERNS_REPO_PATH = os.environ.get(
    "PATTERNS_REPO_PATH",
    os.path.join(
        os.environ.get("HOME", ""),
        "validated_patterns/hybrid-mesh-platform",
    ),
)

# Showroom chart: values file with workshop title
SHOWROOM_VALUES = "charts/all/showroom/values.yaml"
ORIG_TITLE = "Hybrid Mesh Platform Workshop"
NEW_TITLE = "Hybrid Mesh Platform Workshop - VP QE"


@pytest.mark.modify_web_content
def test_modify_web_content(openshift_dyn_client):
    """
    E2E GitOps test: modify showroom values, push to Git, verify site updates.
    Validates the full GitOps loop: Git → Argo CD → OpenShift → HTTP.
    """
    logger.info("Finding showroom route URL")
    route = None
    try:
        for route in Route.get(
            dyn_client=openshift_dyn_client,
            namespace="showroom",
            name="showroom",
        ):
            logger.info(f"Showroom route host: {route.instance.spec.host}")
    except Exception as exc:
        err_msg = f"showroom route not found in 'showroom' namespace: {exc}"
        logger.error(f"FAIL: {err_msg}")
        assert False, err_msg

    if route is None:
        err_msg = "No route found for showroom in 'showroom' namespace"
        logger.error(f"FAIL: {err_msg}")
        assert False, err_msg

    url = "https://" + route.instance.spec.host
    try:
        response = requests.get(url, timeout=10, verify=False)
        logger.info(f"Current showroom HTTP {response.status_code}")
    except requests.RequestException as exc:
        err_msg = f"Cannot reach showroom URL {url}: {exc}"
        logger.error(f"FAIL: {err_msg}")
        assert False, err_msg

    # Determine chart file path
    if os.getenv("EXTERNAL_TEST") == "true":
        chart = os.path.join("../..", SHOWROOM_VALUES)
    else:
        chart = os.path.join(PATTERNS_REPO_PATH, SHOWROOM_VALUES)

    if not os.path.exists(chart):
        pytest.skip(
            f"Showroom values file not found at {chart} — skipping GitOps roundtrip."
        )

    logger.info(f"Modifying showroom title in {chart}")
    modify_file_content(
        file_name=chart,
        orig_content=ORIG_TITLE,
        new_content=NEW_TITLE,
    )

    logger.info("Committing and pushing showroom title change")
    cwd = None if os.getenv("EXTERNAL_TEST") == "true" else PATTERNS_REPO_PATH

    git_add = subprocess.run(
        ["git", "add", chart], cwd=cwd, capture_output=True, text=True
    )
    if git_add.returncode != 0:
        logger.error(f"git add failed: {git_add.stderr}")

    git_commit = subprocess.run(
        ["git", "commit", "-m", f"test: update showroom title to '{NEW_TITLE}'"],
        cwd=cwd,
        capture_output=True,
        text=True,
    )
    if git_commit.returncode != 0:
        logger.warning(f"git commit returned non-zero: {git_commit.stderr}")

    push = subprocess.run(
        ["git", "push"], cwd=cwd, capture_output=True, text=True
    )
    if push.returncode != 0:
        logger.error(f"git push failed: {push.stderr}")
    logger.info(push.stdout)

    logger.info(
        f"Waiting up to {CONTENT_UPDATE_TIMEOUT_MINUTES} min for Argo CD to sync "
        "and showroom pod to reload..."
    )
    timeout = time.time() + 60 * CONTENT_UPDATE_TIMEOUT_MINUTES
    new_content = None
    while time.time() < timeout:
        time.sleep(CONTENT_UPDATE_POLL_SECONDS)
        try:
            response = requests.get(url, timeout=10, verify=False)
            new_content = re.search(NEW_TITLE, response.text)
            if new_content:
                break
        except requests.RequestException:
            continue

    # Revert the change so subsequent runs are idempotent
    logger.info("Reverting showroom title change")
    modify_file_content(
        file_name=chart,
        orig_content=NEW_TITLE,
        new_content=ORIG_TITLE,
    )
    subprocess.run(["git", "add", chart], cwd=cwd, capture_output=True, text=True)
    subprocess.run(
        ["git", "commit", "-m", "test: revert showroom title"],
        cwd=cwd,
        capture_output=True,
        text=True,
    )
    subprocess.run(["git", "push"], cwd=cwd, capture_output=True, text=True)

    if new_content is None:
        err_msg = (
            f"Showroom did not reflect updated title '{NEW_TITLE}' "
            f"within {CONTENT_UPDATE_TIMEOUT_MINUTES} minutes"
        )
        logger.error(f"FAIL: {err_msg}")
        assert False, err_msg
    else:
        logger.info("PASS: Showroom reflects GitOps content change.")
