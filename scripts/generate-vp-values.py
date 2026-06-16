#!/usr/bin/env python3
"""Generate charts/region/{hub,east,west}/values.yaml from platform-hub-spoke-config."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(__file__).resolve().parents[2] / "platform-hub-spoke-config"

PUSH_SPOKE_APP_IDS = frozenset({"operators-ci", "operators-platform"})

APP_ARGO_PROJECT: dict[str, str] = {
    "platform-users": "platform",
    "openshift-gitops": "platform",
    "namespaces": "platform",
    "operators": "operators-platform",
    "operators-platform": "operators-platform",
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
    "developer-hub": "workshop",
    "workshop-demos": "workshop",
    "workshop-registration": "workshop",
    "showroom": "workshop",
    "gitlab-operator": "workshop",
    "console-links": "workshop",
    "devspaces": "workshop",
    "vault": "external-secrets",
    "openshift-external-secrets": "external-secrets",
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

HUB_SKIP = {"spoke-components", "spoke-meta-push", "acs-secured-cluster"}


def load_yaml(path: Path) -> dict:
    with path.open(encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def app_entry(app: dict) -> dict:
    app_id = app["id"]
    ns = app.get("destinationNamespace", "default")
    entry: dict = {
        "name": app_id,
        "namespace": ns,
        "argoProject": APP_ARGO_PROJECT.get(app_id, "platform"),
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
        if name != "hub" and app_id in PUSH_SPOKE_APP_IDS:
            continue
        if name != "hub" and app_id == "operators":
            continue
        cg["applications"][app_id] = app_entry(app)
    if name != "hub":
        cg["applications"]["operators-edge"] = {
            "name": "operators-edge",
            "namespace": "openshift-operators",
            "argoProject": "operators-edge",
            "path": "charts/all/operators-edge",
            "syncWave": "2",
        }
    if managed_cluster_groups:
        cg["managedClusterGroups"] = managed_cluster_groups
    return cg


def main() -> None:
    if not SOURCE.is_dir():
        print(f"Legacy source not found: {SOURCE}", file=sys.stderr)
        sys.exit(1)

    hub_src = load_yaml(SOURCE / "values.yaml")
    east_src = load_yaml(SOURCE / "east" / "values.yaml")

    hub_apps = [
        a
        for a in hub_src.get("connectivityLink", {}).get("apps", [])
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
        hub_src.get("connectivityLink", {})
        .get("operators", {})
        .get("subscriptions", [])
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

    spoke_subs = subscriptions_block(
        east_src.get("operators", {}).get("subscriptions", [])
    )
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
        {},
        hub_subs,
        HUB_ARGO_PROJECTS,
        managed_cluster_groups=managed,
    )
    hub_cg["applications"]["operators-platform"] = hub_cg["applications"].pop(
        "operators",
        hub_cg["applications"].get(
            "operators-platform",
            {
                "name": "operators-platform",
                "namespace": "openshift-operators",
                "argoProject": "operators-platform",
                "path": "charts/all/operators-platform",
                "syncWave": "0",
            },
        ),
    )
    hub_cg["applications"]["operators-platform"]["name"] = "operators-platform"
    hub_cg["applications"]["operators-platform"]["argoProject"] = "operators-platform"
    hub_cg["applications"]["operators-platform"][
        "path"
    ] = "charts/all/operators-platform"
    hub_cg["applications"]["fleet-pull-overview"] = {
        "name": "fleet-pull-overview",
        "namespace": "openshift-gitops",
        "argoProject": "fleet-pull",
        "path": "charts/all/fleet-pull-overview",
        "syncWave": "1",
    }
    hub_cg["applications"]["vault"] = {
        "name": "vault",
        "namespace": "vault",
        "argoProject": "external-secrets",
        "chart": "hashicorp-vault",
        "chartVersion": "0.1.*",
    }
    hub_cg["applications"]["openshift-external-secrets"] = {
        "name": "openshift-external-secrets",
        "namespace": "external-secrets",
        "argoProject": "external-secrets",
        "chart": "openshift-external-secrets",
        "chartVersion": "0.0.*",
    }

    east_cg = build_cluster_group(
        "east", east_apps, {}, spoke_subs, SPOKE_ARGO_PROJECTS
    )
    west_cg = build_cluster_group(
        "west", east_apps, {}, spoke_subs, SPOKE_ARGO_PROJECTS
    )
    for cg in (east_cg, west_cg):
        cg["applications"]["openshift-external-secrets"] = {
            "name": "openshift-external-secrets",
            "namespace": "external-secrets",
            "argoProject": "external-secrets",
            "chart": "openshift-external-secrets",
            "chartVersion": "0.0.*",
        }

    for region, cg in [
        ("hub", hub_cg),
        ("east", east_cg),
        ("west", west_cg),
    ]:
        out = ROOT / "charts" / "region" / region / "values.yaml"
        existing = (
            yaml.safe_load(out.read_text(encoding="utf-8")) if out.exists() else {}
        )
        wrapped = {
            "main": existing.get(
                "main",
                {
                    "clusterGroupName": region,
                    "multiSourceConfig": {
                        "enabled": True,
                        "clusterGroupChartVersion": "0.9.*",
                        "helmRepoUrl": "https://charts.validatedpatterns.io",
                    },
                },
            ),
            "clusterGroup": cg,
        }
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(
            yaml.dump(wrapped, sort_keys=False, default_flow_style=False),
            encoding="utf-8",
        )
    print("Wrote charts/region/{hub,east,west}/values.yaml from legacy source")
    subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "apply-vp-argo-layout.py")], check=True
    )


if __name__ == "__main__":
    main()
