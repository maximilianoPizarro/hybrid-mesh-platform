---
title: Annotations & Labels Reference
weight: 13
---

# Annotations & Labels Reference

This page documents every Kubernetes **label** and **annotation** that activates a feature in this platform — on **Namespaces**, **Pods**, **Deployments**, **Secrets**, or **CRs**. Use it as a quick-reference when onboarding namespaces, enabling monitoring, or enrolling workloads.

---

## Namespace-level labels

These labels are applied via `charts/all/namespaces` (sync-wave 0) and control which platform features are active per namespace.

### Ambient mesh enrollment

| Label | Value | Effect |
| ----- | ----- | ------ |
| `istio.io/dataplane-mode` | `ambient` | Enrolls all pods in the namespace into the **Istio ambient dataplane** (ztunnel L4 mTLS + telemetry). No sidecar injection required. |

**Enrolled namespaces** (set in `charts/all/namespaces/templates/all.yaml`):

| Namespace | Purpose |
| --------- | ------- |
| `industrial-edge-stormshift-messaging` | Kafka messaging (Stormshift) |
| `industrial-edge-ml-workspace` | ML workspace |
| `industrial-edge-ci` | CI/CD pipelines |
| `ml-development` | ML development |
| `hub-gateway-system` | Hub gateway (also in `charts/all/hub-gateway/templates/namespace.yaml`) |
| `spoke-gateway-system` | Spoke gateway (also in `charts/all/spoke-gateway/templates/all.yaml`) |
| `redhat-ods-operator` | OpenShift AI operator |
| `openshift-cluster-observability-operator` | Observability stack |
| `developer-hub` | Red Hat Developer Hub |
| `devspaces` | Dev Spaces |
| `redhat-connectivity-link-operator` | Connectivity Link |

**Excluded from mesh** (no `istio.io/dataplane-mode` label):

| Namespace | Reason |
| --------- | ------ |
| `industrial-edge-tst-all` | ztunnel/istiod auth issues break hub→spoke gateway and WebSocket dashboard traffic |
| `spoke-gateway-system` | Same — use direct TCP + Gateway API ReferenceGrant instead of ambient HBONE |
| `stackrox` | ACS Central ↔ PostgreSQL TLS breaks under ambient interception |
| `gitea` | Gitea init container → PostgreSQL via ClusterIP conflicts with ztunnel |
| `industrial-edge-data-lake` | MinIO / data lake in-namespace patterns |

### OpenShift AI / RHOAI dashboard

| Label | Value | Effect |
| ----- | ----- | ------ |
| `opendatahub.io/dashboard` | `"true"` | Registers the namespace in the **RHOAI dashboard** project list. |

Applied in `charts/all/industrial-edge-data-science-project/templates/all.yaml` on the `ml-development` namespace.

---

## Pod-level labels (selector targets)

These labels are **set by operators** on pods and are used by `PodMonitor`/`ServiceMonitor` selectors to activate scraping.

### Kafka broker metrics

| Label | Value | Selector in | Effect |
| ----- | ----- | ----------- | ------ |
| `strimzi.io/name` | `<cluster>-kafka` | `PodMonitor` `strimzi-kafka-metrics` | **User Workload Monitoring** scrapes Kafka broker JMX/exporter metrics on port `tcp-prometheus` (path `/metrics`). |

Defined in `charts/all/istio-monitoring/templates/all.yaml`. Strimzi automatically sets this label on broker pods.

### Istio gateway metrics

| Label | Value | Selector in | Effect |
| ----- | ----- | ----------- | ------ |
| `gateway.istio.io/managed` | *(any, operator `Exists`)* | `PodMonitor` `istio-mesh-metrics` | Scrapes **Envoy stats** from Istio-managed gateway/waypoint pods on port `metrics` (path `/stats/prometheus`). |

### ztunnel metrics

| Label | Value | Selector in | Effect |
| ----- | ----- | ----------- | ------ |
| `app` | `ztunnel` | `PodMonitor` `ztunnel-metrics` | Scrapes **ztunnel** L4 stats (port `ztunnel-stats`, path `/stats/prometheus`). |

### istiod metrics

| Label | Value | Selector in | Effect |
| ----- | ----- | ----------- | ------ |
| `app` | `istiod` | `ServiceMonitor` `istiod-monitor` | Scrapes **istiod** control plane metrics (port `http-monitoring`, path `/metrics`). |

---

## Gateway / Istio annotations

| Annotation | Value | Resource | File | Effect |
| ---------- | ----- | -------- | ---- | ------ |
| `networking.istio.io/service-type` | `ClusterIP` | `Gateway` (gateway.networking.k8s.io) | `charts/all/hub-gateway/templates/gateway.yaml`, `charts/all/spoke-gateway/templates/all.yaml` | Forces the auto-generated Service for the Istio gateway to be **ClusterIP** instead of LoadBalancer. |

## Gateway / Istio labels

| Label | Value | Resource | File | Effect |
| ----- | ----- | -------- | ---- | ------ |
| `istio.io/waypoint-for` | `service` | `Gateway` (class `istio-waypoint`) | `charts/all/servicemeshoperator3/templates/all.yaml` | Declares this waypoint Gateway provides **L7 proxying** for services in the namespace (ambient mesh). |

---

## ConfigMap labels (Developer Hub)

| Label | Value | Resource | File | Effect |
| ----- | ----- | -------- | ---- | ------ |
| `rhdh.redhat.com/ext-config-sync` | `"true"` | `ConfigMap` | `charts/all/developer-hub/templates/all.yaml`, `catalog-users.yaml` | RHDH operator **syncs** the ConfigMap content into the Backstage runtime as external configuration. |

---

## Backstage catalog annotations (Developer Hub entities)

Applied on `catalog-info.yaml` entities (static catalog or scaffolder-generated).

| Annotation | Example | Effect |
| ---------- | ------- | ------ |
| `backstage.io/kubernetes-id` | `line-dashboard` | Label selector for workloads in Topology/Kubernetes tab |
| `backstage.io/kubernetes-namespace` | `industrial-edge-tst-all` | Namespace to query on the target cluster |
| `backstage.io/kubernetes-cluster` | `east`, `west`, or `hub` | **Which cluster** the Kubernetes plugin uses — required for spoke visibility |
| `janus-idp.io/tekton` | `industrial-edge-ci` or target namespace | Enables **Tekton CI** tab for PipelineRuns in that namespace |
| `backstage.io/source-location` | `url:https://gitea-gitea.../owner/repo` | Links entity to Gitea repository |
| `quay.io/repository-slug` | `maximilianopizarro/my-app` | Public Quay repo reference for catalog |
| `argocd/app-name` | `field-content-industrial-edge-tst` | Argo CD application hint (when ArgoCD plugin enabled) |
| `kairos.io/environment` | `dev`, `qa`, or `prod` | Documents scaffold tier on the catalog entity (see [Kairos](community/kairos.html)) |

**Scaffolder-generated links** (in `metadata.links`, not annotations):

| Link title | Purpose |
| ---------- | ------- |
| Source Code (Gitea) | Repository browser |
| Documentation | Raw `README.md` on Gitea |
| Open in DevSpaces | `https://devspaces.<domain>/#<gitea-repo-url>` |

---

## Kairos labels and catalog annotations {#kairos-labels-and-catalog-annotations}

Kairos enrollment uses **labels on workloads** and optional **catalog annotations** on Developer Hub entities. Scan policies use a **CR**, not Deployment annotations.

### Deployment / pod labels (required for environment agents)

| Label | Example | Resource | Effect |
| ----- | ------- | -------- | ------ |
| `kairos.io/managed` | `"true"` | `Deployment` metadata **and** pod template | `KairosAgent` with `labelSelector: kairos.io/managed=true` includes the workload |
| `kairos.io/environment` | `dev`, `qa`, `prod` | `Deployment` metadata **and** pod template | Matches scaffold parameter; pairs with namespace suffix `-dev`, `-qa`, `-prod` |

Source: `docs/assets/backstage/software-templates/industrial-edge/skeleton/manifests/machine-sensor.yaml`

```yaml
metadata:
  labels:
    kairos.io/managed: "true"
    kairos.io/environment: dev
spec:
  template:
    metadata:
      labels:
        kairos.io/managed: "true"
        kairos.io/environment: dev
```

### Catalog annotation (Developer Hub only)

| Annotation | Example | Resource | Effect |
| ---------- | ------- | -------- | ------ |
| `kairos.io/environment` | `dev` | `Component` in `catalog-info.yaml` | Shown on entity metadata; **does not** enroll the workload without `kairos.io/managed` on Deployments |

### SmartScalingPolicy CR (platform baseline sensors)

Not an annotation — GitOps on **spokes** creates `SmartScalingPolicy` in `kairos-system` targeting `machine-sensor-1` and `machine-sensor-2` in `industrial-edge-tst-all`. See [Kairos — SmartScalingPolicy sizing](community/kairos.html#smartscalingpolicy-sizing).

| CR label | Value | Effect |
| -------- | ----- | ------ |
| `kairos.io/policy-type` | `sensor-scan` | Identifies platform scan policies in `charts/all/kairos/templates/sensor-scan-policies.yaml` |

---

## CR-level annotations (KServe)

| Annotation | Value | Resource | File | Effect |
| ---------- | ----- | -------- | ---- | ------ |
| `serving.kserve.io/deploymentMode` | `ModelMesh` | `InferenceService` | `charts/all/industrial-edge-tst/templates/anomaly-detection.yaml` | Routes inference through **ModelMesh** instead of default Knative Serverless mode. |

---

## Cluster secret labels (ACM / Argo CD)

These labels are on Argo CD cluster secrets created by ACM's `GitOpsCluster` controller.

| Label | Value | Resource | Effect |
| ----- | ----- | -------- | ------ |
| `argocd.argoproj.io/secret-type` | `cluster` | `Secret` | Marks the secret as an **Argo CD cluster registration**. |
| `apps.open-cluster-management.io/acm-cluster` | `true` | `Secret` | Identifies ACM-managed cluster secrets. |
| `apps.open-cluster-management.io/cluster-name` | `east` / `west` | `Secret` | Cluster name for ACM integration. |
| `cluster.open-cluster-management.io/clusterset` | `global` | `Secret` | Binds the cluster to the **global** ManagedClusterSet. |
| `name` | `east` / `west` | `Secret` | Cluster identifier used by ApplicationSet generators. |
| `region` | `east` / `west` | `Secret` | Region label for Placement selectors. |
| `clusterDomain` | `apps.<cluster>.<domain>` | `Secret` | **Custom label** added for ApplicationSet to derive the cluster's app domain. |

---

## ManagedCluster labels (ACM fleet)

These labels are set on `ManagedCluster` resources for Placement-based cluster selection.

| Label | Value | Effect |
| ----- | ----- | ------ |
| `cluster.open-cluster-management.io/clusterset` | `global` | Binds the cluster to a `ManagedClusterSet` for `ManagedClusterSetBinding` + `Placement`. |
| `region` | `east` / `west` | Example label used by `Placement` label selectors. |
| `environment` | `prod` / `dev` | Example label for environment-based placement. |
| `vendor` | `OpenShift` | Auto-set by ACM during import. |

---

## ApplicationSet-generated app labels

Apps created by the `fleet-spoke-push` ApplicationSet carry:

| Label | Value | Effect |
| ----- | ----- | ------ |
| `app.kubernetes.io/part-of` | `platform-hub-spoke` | Groups all platform apps for Argo CD filtering. |
| `apps.open-cluster-management.io/cluster-set` | `global` | Enables ACM Fleet Management UI to discover spoke apps. |

---

## Monitor labels (Grafana Operator)

| Label | Value | Resource | Effect |
| ----- | ----- | -------- | ------ |
| `dashboards` | `grafana` | `Grafana`, `GrafanaDatasource`, `GrafanaDashboard` | **Instance selector** — binds datasources and dashboards to the correct Grafana instance. |

Defined in `charts/all/observability/templates/all.yaml` and `charts/all/spoke-dashboards/templates/local-metrics.yaml`.

---

## PodMonitor / ServiceMonitor common label

| Label | Value | Resource | Effect |
| ----- | ----- | -------- | ------ |
| `release` | `openshift-user-workload-monitoring` | `PodMonitor`, `ServiceMonitor` | Required for **OpenShift User Workload Monitoring** to discover and activate the monitor. |

---

## Deployment labels (OpenShift console hints)

| Label | Value | Resource | Effect |
| ----- | ----- | -------- | ------ |
| `app.kubernetes.io/part-of` | `industrial-edge` | `Deployment` | Groups workloads in the **OpenShift Topology** view. |
| `app.openshift.io/runtime` | `python` / `email` / etc. | `Deployment` | Shows runtime **icon** in OpenShift console Topology. |

---

## What is NOT annotation-driven

Several products in this platform do **not** use namespace or deployment annotations for enrollment:

| Product | Enrollment mechanism |
| ------- | -------------------- |
| **ACS** | `SecuredCluster` CR + TLS Secrets from init bundles |
| **ACM** | `ManagedCluster` import (not workload annotations) |
| **Skupper** | `Site`, `Listener`, `Connector` CRs |
| **Camel K** | `IntegrationPlatform` CR scope |
| **Tekton** | `TektonConfig` cluster-wide operator |
| **Connectivity Link** | `Gateway`, `HTTPRoute`, Kuadrant policy CRs |
| **Developer Hub** | `Backstage` CR + `app-config-*` ConfigMaps |
| **Kafka Console** | `Console` CR with `kafkaClusters[]` references |
| **Kairos** | `kairos.io/managed` label + `KairosAgent` / `SmartScalingPolicy` CRs |

---

## Quick checklist — onboarding a new namespace

1. Add the namespace to `charts/all/namespaces/templates/all.yaml`
2. Decide mesh enrollment:
   - **Yes** → add label `istio.io/dataplane-mode: ambient`
   - **No** → omit the label (document reason in the template)
3. If the namespace has Kafka brokers, ensure `PodMonitor` selectors match (`strimzi.io/name: <cluster>-kafka`)
4. If you need RHOAI dashboard visibility, add `opendatahub.io/dashboard: "true"`
5. Add the component to the ApplicationSet component list in `charts/all/acm-hub-spoke/templates/applicationset.yaml`
6. Add a waypoint `Gateway` (class `istio-waypoint`) if L7 policy or HTTP metrics are needed

---

**See also:** [Red Hat Products — Operator Discovery](products/) for per-product CRD details.
