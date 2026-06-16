#!/usr/bin/env python3
"""Apply Argo Project taxonomy and PUSH/PULL split to charts/region/*/values.yaml."""

from __future__ import annotations

from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]

PUSH_SPOKE_APP_IDS = frozenset({"operators-ci", "operators-platform"})

APP_ARGO_PROJECT: dict[str, str] = {
    "platform-users": "platform",
    "openshift-gitops": "platform",
    "namespaces": "platform",
    "operators": "operators-platform",
    "operators-platform": "operators-platform",
    "operators-ci": "operators-ci",
    "operators-edge": "operators-edge",
    "acm-operator": "fleet",
    "acm-hub-spoke": "fleet",
    "fleet-pull-overview": "fleet-pull",
    "acs-operator": "security",
    "acs-init-bundle-sync": "security",
    "acs-secured-cluster": "security",
    "kairos": "security",
    "servicemeshoperator3": "mesh",
    "rhcl-operator": "mesh",
    "hub-gateway": "mesh",
    "service-interconnect": "mesh",
    "spoke-gateway": "mesh",
    "spoke-interconnect": "mesh",
    "skupper-network-observer": "mesh",
    "observability": "observability",
    "kiali": "observability",
    "grafana-dashboards": "observability",
    "istio-monitoring": "observability",
    "opentelemetry": "observability",
    "distributed-tracing": "observability",
    "kafka-console": "observability",
    "spoke-dashboards": "observability",
    "industrial-edge-tst": "industrial-edge",
    "industrial-edge-stormshift": "industrial-edge",
    "industrial-edge-pipelines": "industrial-edge",
    "industrial-edge-data-science-cluster": "industrial-edge",
    "industrial-edge-data-lake": "industrial-edge",
    "industrial-edge-data-science-project": "industrial-edge",
    "ie-anomaly-alerter": "industrial-edge",
    "camel-dashboard-openshift": "industrial-edge",
    "industrial-edge-minio": "ai",
    "openshift-ai-hub": "ai",
    "neuroface": "ai",
    "cnv-example": "ai",
    "developer-hub": "workshop",
    "workshop-demos": "workshop",
    "workshop-registration": "workshop",
    "showroom": "workshop",
    "workshop-kuadrant-apis": "workshop",
    "gitlab-operator": "workshop",
    "console-links": "workshop",
    "mcp-gateway": "workshop",
    "devspaces": "workshop",
    "quay-registry": "workshop",
    "mailpit": "workshop",
    "mailpit-templates": "workshop",
    "kubecost": "observability",
    "vault": "external-secrets",
    "openshift-external-secrets": "external-secrets",
    "vault-maas-external-secrets": "external-secrets",
    "vault-demo-auth": "external-secrets",
}

HUB_ARGO_PROJECTS = [
    "platform",
    "operators-platform",
    "fleet",
    "fleet-push",
    "fleet-pull",
    "security",
    "mesh",
    "observability",
    "workshop",
    "ai",
    "external-secrets",
]

SPOKE_ARGO_PROJECTS = [
    "platform",
    "operators-edge",
    "security",
    "mesh",
    "observability",
    "industrial-edge",
    "workshop",
    "external-secrets",
    "fleet-pull",
]

HUB_ONLY = {
    "acm-operator",
    "acm-hub-spoke",
    "fleet-pull-overview",
    "acs-operator",
    "acs-init-bundle-sync",
    "developer-hub",
    "workshop-demos",
    "workshop-registration",
    "showroom",
    "workshop-kuadrant-apis",
    "gitlab-operator",
    "hub-gateway",
    "grafana-dashboards",
    "kafka-console",
    "skupper-network-observer",
    "quay-registry",
    "kubecost",
    "openshift-ai-hub",
    "industrial-edge-minio",
    "neuroface",
    "cnv-example",
    "mailpit",
    "mailpit-templates",
    "mcp-gateway",
    "distributed-tracing",
    "vault",
    "vault-maas-external-secrets",
}


def load(path: Path) -> dict:
    with path.open(encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def save(path: Path, data: dict) -> None:
    path.write_text(
        yaml.dump(data, sort_keys=False, default_flow_style=False, allow_unicode=True),
        encoding="utf-8",
    )


def ensure_path(entry: dict, app_id: str) -> None:
    if entry.get("chart") or entry.get("repoURL"):
        return
    if "path" not in entry:
        entry["path"] = f"charts/all/{app_id}"


def transform_hub(cg: dict) -> None:
    cg["argoProjects"] = HUB_ARGO_PROJECTS
    apps = cg.get("applications", {})
    if "operators" in apps:
        apps["operators-platform"] = {
            **apps.pop("operators"),
            "name": "operators-platform",
            "argoProject": "operators-platform",
            "path": "charts/all/operators-platform",
        }
    apps["fleet-pull-overview"] = {
        "name": "fleet-pull-overview",
        "namespace": "openshift-gitops",
        "argoProject": "fleet-pull",
        "path": "charts/all/fleet-pull-overview",
        "syncWave": "1",
    }
    for app_id, entry in apps.items():
        project = APP_ARGO_PROJECT.get(app_id, "platform")
        entry["argoProject"] = project
        ensure_path(entry, app_id)


def transform_spoke(cg: dict) -> None:
    cg["argoProjects"] = SPOKE_ARGO_PROJECTS
    apps = cg.get("applications", {})
    for push_id in list(PUSH_SPOKE_APP_IDS):
        apps.pop(push_id, None)
    if "operators" in apps:
        del apps["operators"]
    apps["operators-edge"] = {
        "name": "operators-edge",
        "namespace": "openshift-operators",
        "argoProject": "operators-edge",
        "path": "charts/all/operators-edge",
        "syncWave": "2",
    }
    for app_id, entry in list(apps.items()):
        project = APP_ARGO_PROJECT.get(app_id, "platform")
        entry["argoProject"] = project
        ensure_path(entry, app_id)
        entry.setdefault("name", app_id)


def main() -> None:
    hub = load(ROOT / "charts/region/hub/values.yaml")
    east = load(ROOT / "charts/region/east/values.yaml")
    west = load(ROOT / "charts/region/west/values.yaml")

    transform_hub(hub["clusterGroup"])
    transform_spoke(east["clusterGroup"])
    transform_spoke(west["clusterGroup"])

    save(ROOT / "charts/region/hub/values.yaml", hub)
    save(ROOT / "charts/region/east/values.yaml", east)
    save(ROOT / "charts/region/west/values.yaml", west)
    print("Updated charts/region/{hub,east,west}/values.yaml")


if __name__ == "__main__":
    main()
