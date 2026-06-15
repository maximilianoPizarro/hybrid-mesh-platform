#!/usr/bin/env python3
"""Sync cluster ingress/API domains into the field-content Argo CD Application.

Hub mode: read ManagedCluster + local ingress, patch hub field-content, push
hub domain to spokes via ManifestWork ConfigMap.

Spoke mode: read fleet-cross-cluster-config ConfigMap, patch local field-content
with clusters.hub.domain and global.hubClusterDomain.
"""

from __future__ import annotations

import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

try:
    import yaml
except ImportError:
    print("PyYAML required; install with: pip install pyyaml", file=sys.stderr)
    sys.exit(2)

SA_TOKEN_PATH = Path("/var/run/secrets/kubernetes.io/serviceaccount/token")
SA_CA_PATH = Path("/var/run/secrets/kubernetes.io/serviceaccount/ca.crt")
API_HOST = os.environ.get("KUBERNETES_SERVICE_HOST", "kubernetes.default.svc")
API_PORT = os.environ.get("KUBERNETES_SERVICE_PORT", "443")
API_BASE = f"https://{API_HOST}:{API_PORT}"

MODE = os.environ.get("SYNC_MODE", "hub")
FIELD_CONTENT_APP = os.environ.get("FIELD_CONTENT_APP", "field-content")
ARGOCD_NS = os.environ.get("ARGOCD_NAMESPACE", "openshift-gitops")
SPOKE_CLUSTERS = [
    c.strip()
    for c in os.environ.get("SPOKE_CLUSTERS", "east,west").split(",")
    if c.strip()
]
CONFIGMAP_NAME = os.environ.get("CONFIGMAP_NAME", "fleet-cross-cluster-config")
CLUSTER_NAME = os.environ.get("CLUSTER_NAME", "")


def api_request(
    method: str, path: str, body: Any = None, content_type: str = "application/json"
) -> Any:
    token = SA_TOKEN_PATH.read_text().strip()
    ctx = ssl.create_default_context(cafile=str(SA_CA_PATH))
    headers = {"Authorization": f"Bearer {token}"}
    data = None
    if body is not None:
        data = json.dumps(body).encode() if isinstance(body, dict) else body
        headers["Content-Type"] = content_type
    req = urllib.request.Request(
        f"{API_BASE}{path}", data=data, method=method, headers=headers
    )
    with urllib.request.urlopen(req, context=ctx, timeout=120) as resp:
        raw = resp.read().decode()
        return json.loads(raw) if raw else {}


def api_patch_merge(path: str, patch: dict) -> None:
    token = SA_TOKEN_PATH.read_text().strip()
    ctx = ssl.create_default_context(cafile=str(SA_CA_PATH))
    body = json.dumps(patch).encode()
    req = urllib.request.Request(
        f"{API_BASE}{path}",
        data=body,
        method="PATCH",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/merge-patch+json",
        },
    )
    with urllib.request.urlopen(req, context=ctx, timeout=120):
        return


def api_patch_strategic(path: str, patch: dict) -> None:
    token = SA_TOKEN_PATH.read_text().strip()
    ctx = ssl.create_default_context(cafile=str(SA_CA_PATH))
    body = json.dumps(patch).encode()
    req = urllib.request.Request(
        f"{API_BASE}{path}",
        data=body,
        method="PATCH",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/strategic-merge-patch+json",
        },
    )
    with urllib.request.urlopen(req, context=ctx, timeout=120):
        return


def deep_merge(base: dict, overlay: dict) -> dict:
    result = dict(base)
    for key, value in overlay.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = value
    return result


def api_host_to_apps_domain(host: str) -> str:
    if not host:
        return ""
    if host.startswith("api."):
        return "apps." + host[4:]
    return host


def api_url_to_apps_domain(api_url: str) -> str:
    host = urlparse(api_url).hostname or ""
    return api_host_to_apps_domain(host)


def get_ingress_apps_domain() -> str:
    try:
        ic = api_request(
            "GET",
            "/apis/operator.openshift.io/v1/namespaces/openshift-ingress-operator/ingresscontrollers/default",
        )
        domain = ic.get("status", {}).get("domain", "")
        if domain:
            return domain.lstrip(".")
    except urllib.error.HTTPError:
        pass
    return ""


def get_managed_cluster(name: str) -> dict | None:
    try:
        return api_request(
            "GET", f"/apis/cluster.open-cluster-management.io/v1/managedclusters/{name}"
        )
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise


def cluster_available(mc: dict) -> bool:
    for cond in mc.get("status", {}).get("conditions", []):
        if (
            cond.get("type") == "ManagedClusterConditionAvailable"
            and cond.get("status") == "True"
        ):
            return True
    return False


def cluster_api_url(mc: dict) -> str:
    claims = mc.get("status", {}).get("clusterClaims", [])
    for claim in claims:
        # ACM 2.16+ exposes apiserverurl.openshift.io; older clusters used kube-apiserver.
        if claim.get("resource") == "kube-apiserver" or claim.get("name") in (
            "kube-apiserver",
            "apiserverurl.openshift.io",
        ):
            return claim.get("value", "")
    return ""


def load_helm_values(app: dict) -> dict:
    helm = app.get("spec", {}).get("source", {}).get("helm", {})
    if helm.get("valuesObject"):
        return dict(helm["valuesObject"])
    raw = helm.get("values", "") or ""
    if not raw.strip():
        return {}
    loaded = yaml.safe_load(raw)
    return loaded if isinstance(loaded, dict) else {}


def save_helm_values(app: dict, values: dict) -> dict:
    merged = dict(app)
    spec = merged.setdefault("spec", {})
    source = spec.setdefault("source", {})
    helm = source.setdefault("helm", {})
    helm["values"] = yaml.dump(values, default_flow_style=False, sort_keys=False)
    helm.pop("valuesObject", None)
    return merged


def get_field_content_app() -> dict | None:
    try:
        return api_request(
            "GET",
            f"/apis/argoproj.io/v1alpha1/namespaces/{ARGOCD_NS}/applications/{FIELD_CONTENT_APP}",
        )
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise


def patch_field_content_values(patch: dict) -> bool:
    app = get_field_content_app()
    if not app:
        print(
            f"Application {FIELD_CONTENT_APP} not found in {ARGOCD_NS}; skipping patch"
        )
        return False
    current = load_helm_values(app)
    merged = deep_merge(current, patch)
    if merged == current:
        print("field-content helm values already up to date")
        return True
    updated = save_helm_values(app, merged)
    api_patch_merge(
        f"/apis/argoproj.io/v1alpha1/namespaces/{ARGOCD_NS}/applications/{FIELD_CONTENT_APP}",
        {"spec": updated["spec"]},
    )
    print(f"Patched {FIELD_CONTENT_APP} helm values")
    return True


def hub_domain_from_app(app: dict) -> str:
    values = load_helm_values(app)
    deployer = values.get("deployer") or {}
    domain = deployer.get("domain") or values.get("clusterDomain") or ""
    if domain and domain != "apps.cluster.example.com":
        return domain
    return ""


def build_hub_patch(app: dict | None) -> dict | None:
    hub_domain = get_ingress_apps_domain()
    if not hub_domain and app:
        hub_domain = hub_domain_from_app(app)
    if not hub_domain:
        print("WARN: hub apps domain not discovered yet")
        return None

    hub_api = ""
    ic_api = ""
    try:
        ic_api = api_request(
            "GET", "/apis/config.openshift.io/v1/infrastructures/cluster"
        )
        hub_api = ic_api.get("status", {}).get("apiServerURL", "")
    except urllib.error.HTTPError:
        pass

    clusters: dict[str, dict] = {
        "hub": {"domain": hub_domain},
    }
    if hub_api:
        clusters["hub"]["apiUrl"] = hub_api

    managed: dict[str, dict] = {}
    for name in SPOKE_CLUSTERS:
        mc = get_managed_cluster(name)
        if not mc:
            print(f"ManagedCluster {name} not found yet")
            continue
        if not cluster_available(mc):
            print(f"ManagedCluster {name} not Available yet")
            continue
        api_url = cluster_api_url(mc)
        domain = api_url_to_apps_domain(api_url) if api_url else ""
        if not domain:
            print(f"WARN: could not derive apps domain for {name}")
            continue
        clusters[name] = {"domain": domain}
        if api_url:
            clusters[name]["apiUrl"] = api_url
        managed[name] = {"domain": domain}
        if api_url:
            managed[name]["apiUrl"] = api_url

    if len(clusters) <= 1 and not managed:
        return None

    return {
        "global": {"hubClusterDomain": hub_domain},
        "clusters": clusters,
        "managedClusters": managed,
    }


def upsert_manifestwork(cluster: str, hub_domain: str, hub_api: str) -> None:
    name = f"fleet-cross-cluster-config-{cluster}"
    manifest = {
        "apiVersion": "v1",
        "kind": "ConfigMap",
        "metadata": {"name": CONFIGMAP_NAME, "namespace": ARGOCD_NS},
        "data": {
            "hub-domain": hub_domain,
            "hub-api-url": hub_api or "",
            "updated-at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        },
    }
    body = {
        "apiVersion": "work.open-cluster-management.io/v1",
        "kind": "ManifestWork",
        "metadata": {"name": name, "namespace": cluster},
        "spec": {
            "deleteOption": {"propagationPolicy": "Orphan"},
            "manifestConfigs": [
                {
                    "resourceIdentifier": {
                        "group": "",
                        "resource": "configmaps",
                        "namespace": ARGOCD_NS,
                        "name": CONFIGMAP_NAME,
                    },
                    "updateStrategy": {"type": "Update"},
                }
            ],
            "workloadManifests": [manifest],
        },
    }
    path = f"/apis/work.open-cluster-management.io/v1/namespaces/{cluster}/manifestworks/{name}"
    try:
        api_request("GET", path)
        api_patch_strategic(path, {"spec": body["spec"]})
        print(f"Updated ManifestWork {name}")
    except urllib.error.HTTPError as e:
        if e.code == 404:
            api_request(
                "POST",
                f"/apis/work.open-cluster-management.io/v1/namespaces/{cluster}/manifestworks",
                body,
            )
            print(f"Created ManifestWork {name}")
        else:
            raise


def run_hub() -> int:
    app = get_field_content_app()
    patch = build_hub_patch(app)
    if not patch:
        print("Nothing to sync on hub yet")
        return 0
    patch_field_content_values(patch)
    hub_domain = patch["global"]["hubClusterDomain"]
    hub_api = patch.get("clusters", {}).get("hub", {}).get("apiUrl", "")
    for name in SPOKE_CLUSTERS:
        mc = get_managed_cluster(name)
        if mc and cluster_available(mc):
            try:
                upsert_manifestwork(name, hub_domain, hub_api)
            except urllib.error.HTTPError as e:
                print(f"WARN: ManifestWork for {name} failed ({e.code}): {e.reason}")
    return 0


def run_spoke() -> int:
    try:
        cm = api_request(
            "GET", f"/api/v1/namespaces/{ARGOCD_NS}/configmaps/{CONFIGMAP_NAME}"
        )
    except urllib.error.HTTPError as e:
        if e.code == 404:
            print(f"ConfigMap {CONFIGMAP_NAME} not found; waiting for hub ManifestWork")
            return 0
        raise
    hub_domain = (cm.get("data") or {}).get("hub-domain", "").strip()
    if not hub_domain:
        print("hub-domain empty in ConfigMap")
        return 0
    patch = {
        "global": {"hubClusterDomain": hub_domain},
        "clusters": {"hub": {"domain": hub_domain}},
    }
    hub_api = (cm.get("data") or {}).get("hub-api-url", "").strip()
    if hub_api:
        patch["clusters"]["hub"]["apiUrl"] = hub_api
    patch_field_content_values(patch)
    return 0


def main() -> int:
    print(f"fleet-values-sync mode={MODE} cluster={CLUSTER_NAME or 'hub'}")
    if MODE == "spoke":
        return run_spoke()
    return run_hub()


if __name__ == "__main__":
    sys.exit(main())
