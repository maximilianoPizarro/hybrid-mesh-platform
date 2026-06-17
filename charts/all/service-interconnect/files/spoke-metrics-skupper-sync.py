#!/usr/bin/env python3
"""Ensure prometheus-auth-proxy + Skupper prometheus connectors exist on spokes."""

from __future__ import annotations

import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

SA_TOKEN_PATH = Path("/var/run/secrets/kubernetes.io/serviceaccount/token")
SA_CA_PATH = Path("/var/run/secrets/kubernetes.io/serviceaccount/ca.crt")
API_HOST = os.environ.get("KUBERNETES_SERVICE_HOST", "kubernetes.default.svc")
API_PORT = os.environ.get("KUBERNETES_SERVICE_PORT", "443")
API_BASE = f"https://{API_HOST}:{API_PORT}"
NS = "service-interconnect"
CLUSTERS = [c.strip() for c in os.environ.get("SPOKE_CLUSTERS", "east,west").split(",") if c.strip()]
PROXY_IMAGE = os.environ.get("PROMETHEUS_PROXY_IMAGE", "quay.io/rhpds/nginx:1.25")
VIEW_NAME = "prometheus-connector-check"
MCA_NAME = "spoke-metrics-skupper-repair"

KIND_MAP = {
    "ServiceAccount": "serviceaccounts",
    "ConfigMap": "configmaps",
    "Service": "services",
    "Deployment": "deployments",
    "ClusterRoleBinding": "clusterrolebindings",
    "Connector": "connectors",
}


def api_request(method: str, path: str, body: dict | None = None) -> dict:
    token = SA_TOKEN_PATH.read_text().strip()
    ctx = ssl.create_default_context(cafile=str(SA_CA_PATH))
    headers = {"Authorization": f"Bearer {token}"}
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(f"{API_BASE}{path}", data=data, method=method, headers=headers)
    with urllib.request.urlopen(req, context=ctx, timeout=120) as resp:
        raw = resp.read().decode()
        return json.loads(raw) if raw else {}


def connector_exists(cluster: str, name: str) -> bool:
    try:
        api_request(
            "DELETE",
            f"/apis/view.open-cluster-management.io/v1beta1/namespaces/{cluster}/managedclusterviews/{VIEW_NAME}",
        )
    except urllib.error.HTTPError as e:
        if e.code != 404:
            raise
    body = {
        "apiVersion": "view.open-cluster-management.io/v1beta1",
        "kind": "ManagedClusterView",
        "metadata": {"name": VIEW_NAME},
        "spec": {
            "scope": {
                "apiGroup": "skupper.io",
                "version": "v2alpha1",
                "resource": "connectors",
                "kind": "Connector",
                "name": name,
                "namespace": NS,
            }
        },
    }
    api_request(
        "POST",
        f"/apis/view.open-cluster-management.io/v1beta1/namespaces/{cluster}/managedclusterviews",
        body,
    )
    view_path = f"/apis/view.open-cluster-management.io/v1beta1/namespaces/{cluster}/managedclusterviews/{VIEW_NAME}"
    for _ in range(20):
        view = api_request("GET", view_path)
        for c in view.get("status", {}).get("conditions") or []:
            if c.get("type") == "Processing" and c.get("status") == "False":
                if "not found" in (c.get("message") or "").lower():
                    return False
        if view.get("status", {}).get("result"):
            return True
        time.sleep(2)
    return False


def wait_mca(cluster: str) -> None:
    path = f"/apis/action.open-cluster-management.io/v1beta1/namespaces/{cluster}/managedclusteractions/{MCA_NAME}"
    for _ in range(60):
        try:
            mca = api_request("GET", path)
        except urllib.error.HTTPError as e:
            if e.code == 404:
                time.sleep(2)
                continue
            raise
        for c in mca.get("status", {}).get("conditions") or []:
            ctype = c.get("type", "")
            if ctype in ("Complete", "Completed") and c.get("status") == "True":
                return
            msg = (c.get("message") or "").lower()
            if ctype in ("Complete", "Completed") and "already exists" in msg:
                return
            if ctype in ("Complete", "Completed") and c.get("status") == "False":
                if c.get("reason") in ("Failed", "CreateResourceFailed") and "already exists" in msg:
                    return
                if c.get("reason") in ("Failed", "CreateResourceFailed"):
                    raise RuntimeError(c.get("message", "MCA failed"))
        time.sleep(2)
    raise RuntimeError(f"timeout waiting for MCA on {cluster}")


def apply_resource(cluster: str, manifest: dict) -> None:
    try:
        api_request(
            "DELETE",
            f"/apis/action.open-cluster-management.io/v1beta1/namespaces/{cluster}/managedclusteractions/{MCA_NAME}",
        )
    except urllib.error.HTTPError as e:
        if e.code != 404:
            raise
    kind = manifest.get("kind", "")
    meta = manifest.get("metadata", {})
    kube = {
        "resource": KIND_MAP.get(kind, kind.lower() + "s"),
        "name": meta.get("name"),
        "namespace": meta.get("namespace", NS),
        "template": manifest,
    }
    if kind == "ClusterRoleBinding":
        kube["namespace"] = ""
    body = {
        "apiVersion": "action.open-cluster-management.io/v1beta1",
        "kind": "ManagedClusterAction",
        "metadata": {"name": MCA_NAME, "namespace": cluster},
        "spec": {"actionType": "Create", "kube": kube},
    }
    api_request(
        "POST",
        f"/apis/action.open-cluster-management.io/v1beta1/namespaces/{cluster}/managedclusteractions",
        body,
    )
    wait_mca(cluster)


def manifests_for(cluster: str) -> list[dict]:
    connector_name = f"prometheus-{cluster}"
    nginx_conf = (
        "worker_processes 1;\n"
        "pid /tmp/nginx.pid;\n"
        "error_log /dev/stderr warn;\n"
        "events { worker_connections 64; }\n"
        "http {\n"
        "  client_body_temp_path /tmp/client_temp;\n"
        "  proxy_temp_path /tmp/proxy_temp;\n"
        "  fastcgi_temp_path /tmp/fastcgi_temp;\n"
        "  uwsgi_temp_path /tmp/uwsgi_temp;\n"
        "  scgi_temp_path /tmp/scgi_temp;\n"
        "  server {\n"
        "    listen 9091;\n"
        "    location / {\n"
        "      proxy_pass https://thanos-querier.openshift-monitoring.svc.cluster.local:9091;\n"
        "      proxy_ssl_verify off;\n"
        "      proxy_set_header Authorization \"Bearer PROXY_TOKEN\";\n"
        "      proxy_set_header Host thanos-querier.openshift-monitoring.svc.cluster.local;\n"
        "    }\n"
        "  }\n"
        "}\n"
    )
    return [
        {
            "apiVersion": "v1",
            "kind": "ServiceAccount",
            "metadata": {"name": "prometheus-auth-proxy", "namespace": NS},
        },
        {
            "apiVersion": "rbac.authorization.k8s.io/v1",
            "kind": "ClusterRoleBinding",
            "metadata": {"name": f"prometheus-auth-proxy-{cluster}"},
            "roleRef": {
                "apiGroup": "rbac.authorization.k8s.io",
                "kind": "ClusterRole",
                "name": "cluster-monitoring-view",
            },
            "subjects": [
                {"kind": "ServiceAccount", "name": "prometheus-auth-proxy", "namespace": NS}
            ],
        },
        {
            "apiVersion": "v1",
            "kind": "ConfigMap",
            "metadata": {"name": "prometheus-proxy-config", "namespace": NS},
            "data": {"nginx.conf": nginx_conf},
        },
        {
            "apiVersion": "apps/v1",
            "kind": "Deployment",
            "metadata": {"name": "prometheus-auth-proxy", "namespace": NS},
            "spec": {
                "replicas": 1,
                "selector": {"matchLabels": {"app": "prometheus-auth-proxy"}},
                "template": {
                    "metadata": {"labels": {"app": "prometheus-auth-proxy"}},
                    "spec": {
                        "serviceAccountName": "prometheus-auth-proxy",
                        "initContainers": [
                            {
                                "name": "inject-token",
                                "image": "registry.access.redhat.com/ubi9/ubi-minimal:latest",
                                "command": [
                                    "/bin/sh",
                                    "-c",
                                    "TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token); "
                                    "sed \"s|PROXY_TOKEN|${TOKEN}|g\" /config-template/nginx.conf > /config/nginx.conf",
                                ],
                                "volumeMounts": [
                                    {"name": "config-template", "mountPath": "/config-template"},
                                    {"name": "config", "mountPath": "/config"},
                                ],
                            }
                        ],
                        "containers": [
                            {
                                "name": "nginx",
                                "image": PROXY_IMAGE,
                                "command": [
                                    "/bin/sh",
                                    "-ec",
                                    "mkdir -p /tmp/client_temp /tmp/proxy_temp /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp\n"
                                    "exec nginx -g 'daemon off;' -c /etc/nginx/nginx.conf",
                                ],
                                "ports": [{"containerPort": 9091}],
                                "securityContext": {
                                    "allowPrivilegeEscalation": False,
                                    "capabilities": {"drop": ["ALL"]},
                                    "runAsNonRoot": True,
                                },
                                "volumeMounts": [
                                    {
                                        "name": "config",
                                        "mountPath": "/etc/nginx/nginx.conf",
                                        "subPath": "nginx.conf",
                                    },
                                    {"name": "nginx-cache", "mountPath": "/var/cache/nginx"},
                                    {"name": "nginx-run", "mountPath": "/var/run"},
                                    {"name": "tmp", "mountPath": "/tmp"},
                                ],
                            }
                        ],
                        "volumes": [
                            {"name": "config-template", "configMap": {"name": "prometheus-proxy-config"}},
                            {"name": "config", "emptyDir": {}},
                            {"name": "nginx-cache", "emptyDir": {}},
                            {"name": "nginx-run", "emptyDir": {}},
                            {"name": "tmp", "emptyDir": {}},
                        ],
                    },
                },
            },
        },
        {
            "apiVersion": "v1",
            "kind": "Service",
            "metadata": {"name": "prometheus-auth-proxy", "namespace": NS},
            "spec": {
                "selector": {"app": "prometheus-auth-proxy"},
                "ports": [{"port": 9091, "targetPort": 9091, "protocol": "TCP"}],
            },
        },
        {
            "apiVersion": "skupper.io/v2alpha1",
            "kind": "Connector",
            "metadata": {"name": connector_name, "namespace": NS},
            "spec": {
                "routingKey": connector_name,
                "host": "prometheus-auth-proxy.service-interconnect.svc.cluster.local",
                "port": 9091,
            },
        },
    ]


def main() -> int:
    for cluster in CLUSTERS:
        name = f"prometheus-{cluster}"
        if connector_exists(cluster, name):
            print(f"{cluster}: {name} connector OK")
            continue
        print(f"{cluster}: repairing prometheus Skupper metrics path...")
        for manifest in manifests_for(cluster):
            try:
                apply_resource(cluster, manifest)
                print(f"  applied {manifest['kind']}/{manifest['metadata']['name']}")
            except urllib.error.HTTPError as e:
                if e.code == 409:
                    print(f"  exists {manifest['kind']}/{manifest['metadata']['name']}")
                    continue
                raise
    return 0


if __name__ == "__main__":
    sys.exit(main())
