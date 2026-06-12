#!/usr/bin/env python3
"""Generate VP values-hub/east/west from platform-hub-spoke-config (read-only source)."""
from __future__ import annotations

import re
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(__file__).resolve().parents[2] / "platform-hub-spoke-config"

HUB_ARGO_PROJECT = "hub"
SPOKE_ARGO_PROJECT = "spoke"

# Hub apps: exclude spoke-only IE stack and spoke-components helper
HUB_SKIP = {"spoke-components", "acs-secured-cluster"}

# Spoke-only chart ids (from east/values.yaml)
SPOKE_ONLY = {
    "camel-dashboard-openshift-all",
    "camel-dashboard-openshift",
    "industrial-edge-tst",
    "industrial-edge-stormshift",
    "industrial-edge-pipelines",
    "industrial-edge-data-science-cluster",
    "industrial-edge-data-lake",
    "industrial-edge-data-science-project",
    "ie-anomaly-alerter",
    "spoke-gateway",
    "spoke-interconnect",
    "spoke-dashboards",
    "devspaces",
    "acs-secured-cluster",
}

HUB_NAMESPACES = {
    "open-cluster-management": {},
    "stackrox": {},
    "openshift-gitops": {},
    "developer-hub": {},
    "hub-gateway-system": {},
    "workshop-kuadrant-apis": {},
    "mcp-system": {},
    "gitea": {},
    "service-interconnect": {},
    "mailpit": {},
    "mailpit-templates": {},
    "industrial-edge-ml-workspace": {},
    "kafka-console": {},
    "quay-registry": {},
    "kubecost": {},
    "maas-workshop": {},
    "showroom": {},
    "neuroface": {},
    "cnv-workshop": {},
    "redhat-connectivity-link-operator": {},
    "openshift-cluster-observability-operator": {},
    "openshift-opentelemetry": {},
    "distributed-tracing": {},
    "istio-system": {},
    "kairos-system": {},
    "external-secrets-operator": {"operatorGroup": True, "targetNamespaces": []},
    "external-secrets": {},
    "vault": {},
}

SPOKE_NAMESPACES = {
    "industrial-edge-tst-all": {},
    "industrial-edge-stormshift-messaging": {},
    "industrial-edge-ml-workspace": {},
    "industrial-edge-ci": {},
    "ml-development": {},
    "industrial-edge-data-lake": {},
    "stackrox": {},
    "devspaces": {},
    "camel-dashboard": {},
    "spoke-gateway-system": {},
    "service-interconnect": {},
    "kairos-system": {},
    "openshift-cluster-observability-operator": {},
    "openshift-opentelemetry": {},
    "istio-system": {},
    "redhat-connectivity-link-operator": {},
    "external-secrets-operator": {"operatorGroup": True, "targetNamespaces": []},
    "external-secrets": {},
}


def load_yaml(path: Path) -> dict:
    with path.open(encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def app_entry(app: dict, project: str) -> dict:
    app_id = app["id"]
    ns = app.get("destinationNamespace", "default")
    entry: dict = {
        "name": app_id,
        "namespace": ns,
        "argoProject": project,
    }
    if app.get("repoURL") and app.get("chart"):
        entry["repoURL"] = app["repoURL"]
        entry["chart"] = app["chart"]
        entry["targetRevision"] = app.get("targetRevision", "*")
    else:
        path = app.get("path", app_id)
        if path.startswith("components/"):
            path = path.replace("components/", "charts/all/", 1)
        elif not path.startswith("charts/"):
            entry["path"] = f"charts/all/{path}"
        else:
            entry["path"] = path
    if app.get("syncWave"):
        entry["syncWave"] = app["syncWave"]
    return entry


def subscriptions_block(subs: list) -> dict:
    out = {}
    for sub in subs or []:
        key = re.sub(r"[^a-z0-9]+", "-", sub["name"].lower()).strip("-")
        out[key] = {
            "name": sub["name"],
            "namespace": sub["namespace"],
            "channel": sub["channel"],
            "source": sub.get("source", "redhat-operators"),
        }
    return out


def build_cluster_group(
    name: str,
    apps: list[dict],
    namespaces: dict,
    subscriptions: dict,
    argo_projects: list[str],
    managed_cluster_groups: dict | None = None,
) -> dict:
    cg: dict = {
        "name": name,
        "namespaces": namespaces,
        "subscriptions": subscriptions,
        "argoProjects": argo_projects,
        "sharedValueFiles": [
            "/overrides/values-{{ $.Values.global.clusterPlatform }}.yaml",
            "/overrides/values-{{ $.Values.global.clusterVersion }}-{{ $.Values.clusterGroup.name }}.yaml",
        ],
        "applications": {},
    }
    for app in apps:
        if not app.get("enabled", True):
            continue
        app_id = app["id"]
        project = HUB_ARGO_PROJECT if name == "hub" else SPOKE_ARGO_PROJECT
        cg["applications"][app_id] = app_entry(app, project)
    if managed_cluster_groups:
        cg["managedClusterGroups"] = managed_cluster_groups
    return cg


def main() -> None:
    hub_src = load_yaml(SOURCE / "values.yaml")
    east_src = load_yaml(SOURCE / "east" / "values.yaml")

    hub_apps = [
        a for a in hub_src.get("connectivityLink", {}).get("apps", [])
        if a.get("enabled", True) and a["id"] not in HUB_SKIP
    ]

    east_apps = []
    for a in east_src.get("apps", []):
        aid = a["id"]
        if aid == "camel-dashboard-openshift-all":
            a = dict(a)
            a["id"] = "camel-dashboard-openshift"
            a["path"] = "components/camel-dashboard-openshift"
        east_apps.append(a)

    hub_subs = subscriptions_block(
        hub_src.get("connectivityLink", {}).get("operators", {}).get("subscriptions", [])
    )
    hub_subs["acm"] = {
        "name": "advanced-cluster-management",
        "namespace": "open-cluster-management",
        "channel": "release-2.16",
    }
    hub_subs["eso"] = {
        "name": "openshift-external-secrets-operator",
        "namespace": "external-secrets-operator",
        "channel": "stable-v1",
    }

    spoke_subs = subscriptions_block(east_src.get("operators", {}).get("subscriptions", []))
    spoke_subs["eso"] = {
        "name": "openshift-external-secrets-operator",
        "namespace": "external-secrets-operator",
        "channel": "stable-v1",
    }

    managed = {
        "east": {
            "name": "east",
            "acmlabels": [{"name": "clusterGroup", "value": "east"}],
        },
        "west": {
            "name": "west",
            "acmlabels": [{"name": "clusterGroup", "value": "west"}],
        },
    }

    hub_cg = build_cluster_group(
        "hub",
        hub_apps,
        HUB_NAMESPACES,
        hub_subs,
        ["hub", "platform", "external-secrets"],
        managed_cluster_groups=managed,
    )
    # VP hub stack: vault + ESO (from multicloud-gitops)
    hub_cg["applications"]["vault"] = {
        "name": "vault",
        "namespace": "vault",
        "argoProject": "hub",
        "chart": "hashicorp-vault",
        "chartVersion": "0.1.*",
    }
    hub_cg["applications"]["openshift-external-secrets"] = {
        "name": "openshift-external-secrets",
        "namespace": "external-secrets",
        "argoProject": "hub",
        "chart": "openshift-external-secrets",
        "chartVersion": "0.0.*",
    }

    east_cg = build_cluster_group(
        "east",
        east_apps,
        SPOKE_NAMESPACES,
        spoke_subs,
        ["spoke", "external-secrets"],
    )
    east_cg["applications"]["openshift-external-secrets"] = {
        "name": "openshift-external-secrets",
        "namespace": "external-secrets",
        "argoProject": "spoke",
        "chart": "openshift-external-secrets",
        "chartVersion": "0.0.*",
    }

    west_cg = build_cluster_group(
        "west",
        east_apps,
        SPOKE_NAMESPACES,
        spoke_subs,
        ["spoke", "external-secrets"],
    )
    west_cg["applications"]["openshift-external-secrets"] = {
        "name": "openshift-external-secrets",
        "namespace": "external-secrets",
        "argoProject": "spoke",
        "chart": "openshift-external-secrets",
        "chartVersion": "0.0.*",
    }

    (ROOT / "values-hub.yaml").write_text(
        yaml.dump({"clusterGroup": hub_cg}, sort_keys=False, default_flow_style=False),
        encoding="utf-8",
    )
    (ROOT / "values-east.yaml").write_text(
        yaml.dump({"clusterGroup": east_cg}, sort_keys=False, default_flow_style=False),
        encoding="utf-8",
    )
    (ROOT / "values-west.yaml").write_text(
        yaml.dump({"clusterGroup": west_cg}, sort_keys=False, default_flow_style=False),
        encoding="utf-8",
    )
    print(f"Wrote values-hub.yaml ({len(hub_cg['applications'])} apps)")
    print(f"Wrote values-east.yaml ({len(east_cg['applications'])} apps)")
    print(f"Wrote values-west.yaml ({len(west_cg['applications'])} apps)")


if __name__ == "__main__":
    main()
