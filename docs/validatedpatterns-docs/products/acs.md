---
title: Acs
weight: 16
---

# Advanced Cluster Security

## What problem does it solve?

A three-cluster fleet multiplies attack surface: container images on spokes, runtime behavior in Industrial Edge namespaces, and admission decisions at deploy time. **ACS** centralizes vulnerability management, compliance policies, and runtime detection on the **hub**, while **SecuredCluster** sensors on hub + spokes feed telemetry back to **Central** (`central.stackrox`).

Without ACS, operators rely on per-cluster `oc adm` checks and disconnected scanning tools. This pattern registers **`hub`**, **`east`**, and **`west`** with Central via init bundles — automated on new installs by `charts/all/acs-init-bundle-sync`.

Red Hat **Advanced Cluster Security for Kubernetes (ACS)** centralizes Kubernetes-native security: build-time image scanning, deployment-time policy, and runtime detection.

**Git path:** `charts/all/acs-operator/` (hub), `charts/all/acs-secured-cluster/` (hub + spokes), `charts/all/acs-init-bundle-sync/` (hub automation)

![ACS Central – Cluster registration]({{ site.baseurl }}/assets/images/ACS.png)
{: .mb-4 }
*ACS Central — hub and spoke clusters registered (hub, east, west).*
{: .fs-2 .text-grey-dk-000 }

![ACS Central – Console view]({{ site.baseurl }}/assets/images/ACS-2.png)
{: .mb-4 }
*ACS Central — additional console perspective (policies, vulnerabilities, or runtime visibility).*
{: .fs-2 .text-grey-dk-000 }

## Topology for hub-spoke

| Component | Location | Role |
| --------- | -------- | ---- |
| **Central** | Hub | Policy console, vulnerability DB integration, admission coordination |
| **SecuredCluster** | Hub + spokes | Sensor, collector, and admission control per cluster |

The `stackrox` namespace is listed in **`$noMeshNamespaces`** (`charts/all/namespaces`) — do **not** label it `istio.io/dataplane-mode: ambient`. Ambient ztunnel breaks Central ↔ PostgreSQL TLS and Central becomes unreachable.

Hub and spokes register with Central using **init bundles** (TLS secrets in namespace `stackrox`). Generate once per cluster from Central:

```bash
roxctl -e central.stackrox:443 --password "$ROX_ADMIN_PASSWORD" --insecure-skip-tls-verify \
  central init-bundles generate <cluster-name> --output-secrets - | oc apply -n stackrox -f -
```

Cluster names: `hub`, `east`, `west`. The `rhacs-operator` subscription on spokes is deployed via `openshift-operators` (ApplicationSet `subscriptions` list).

## Helm chart registration (hub + spokes)

### 1. Prerequisites

| App | Cluster | Chart path |
|-----|---------|------------|
| `acs-operator` | Hub | `charts/all/acs-operator` |
| `acs-secured-cluster` | Hub + spokes | `charts/all/acs-secured-cluster` |
| `acs-init-bundle-sync` | Hub only | `charts/all/acs-init-bundle-sync` |

Sync order: operator → `SecuredCluster` CR → init bundle secrets (`collector-tls`, `sensor-tls`, `admission-control-tls`).

### 2. Helm values

**Hub** (`templates/component-applications.yaml`):

```yaml
clusterName: hub
clusterRole: hub
centralEndpoint: central.stackrox.svc:443   # in-cluster
```

**Spokes** (`east/templates/component-applications.yaml`, `west/...`):

```yaml
clusterName: east   # or west
clusterRole: spoke
hubClusterDomain: apps.cluster-<hub-id>.dynamic2.redhatworkshops.io
# centralEndpoint rendered as central-stackrox.<hubClusterDomain>:443
```

RHDP must inject `clusters.hub.domain` on spoke orders so `hubClusterDomain` resolves.

### 3. Automated init bundles (recommended)

Chart `charts/all/acs-init-bundle-sync` runs PostSync Job `acs-init-bundle-sync-hook` and CronJob every 12 hours:

1. Reads `ROX_ADMIN_PASSWORD` from Secret `acs-init-credentials` in `stackrox` (create at runtime — never commit).
2. Runs `roxctl central init-bundles generate` per cluster (`hub`, `east`, `west`).
3. Applies secrets on the hub via in-cluster `oc apply`.
4. Pushes spoke bundles via **ManagedClusterAction** Job on each spoke.

Create the credentials Secret after Central is Ready:

```bash
oc create secret generic acs-init-credentials -n stackrox \
  --from-literal=ROX_ADMIN_PASSWORD='<central-admin-password>'
```

If the Secret is missing, the Job exits successfully with a log message; use manual `roxctl` below.

### 4. Manual init bundles (fallback)

On **each** cluster (or from hub with `oc` context):

```bash
export ROX_ADMIN_PASSWORD='<central-admin-password>'

# Hub
roxctl -e central.stackrox:443 --password "$ROX_ADMIN_PASSWORD" --insecure-skip-tls-verify \
  central init-bundles generate hub --output-secrets - | oc apply -n stackrox -f -

# East / west (run with spoke kubeconfig or from hub after ACM join)
roxctl -e central.stackrox:443 --password "$ROX_ADMIN_PASSWORD" --insecure-skip-tls-verify \
  central init-bundles generate east --output-secrets - | oc apply -n stackrox -f -
```

### 5. Verify registration

```bash
oc get securedcluster -n stackrox
oc get secret -n stackrox | grep -E 'collector-tls|sensor-tls|admission-control-tls'
```

ACS UI → **Platform Configuration → Clusters** should list `hub`, `east`, and `west` (may take a few minutes).

### 6. Troubleshooting

| Symptom | Fix |
|---------|-----|
| Central UI empty clusters | Init bundle secrets missing — run step 3 or 4 |
| Spoke cannot reach Central | Wrong `hubClusterDomain`; verify route `central-stackrox.<hub-domain>` |
| Central unreachable | `stackrox` namespace must **not** use Istio ambient |
| MCA Job fails on spoke | Grant `default` SA in `stackrox` permission to apply secrets, or apply manually on spoke |

### Developer Hub — CVE visibility for userN

| Path | Scope | Status |
|------|-------|--------|
| **Quay plugin** (entity tab) | Images pushed to org `workshop` | Enabled — best option for scaffolded components |
| **Security Insights** (`/rhacs` proxy) | ACS image/deployment CVEs on catalog entities | Optional — set `plugins.acsSecurityInsights.enabled: true` if package exists in RHDH image; inject `rhacsApiToken` via Helm → Secret `developer-hub-oidc-auth` key `RHACS_API_TOKEN` |
| **ACS Central UI** | Full fleet | Facilitator/admin — requires init bundles (above) |

Prerequisite for Security Insights: clusters registered in ACS and a read-only API token from **Platform Configuration → Integrations → API token**.

## Operator discovery

**RHACS controller manager** watches **`SecuredCluster`** CRs inside **`stackrox`** (platform.stackrox.io) plus **`Central`** objects where Central installs live.

Admission/collector assets reconcile once **`collector-tls`**, **`sensor-tls`**, and **`admission-control-tls`** Secrets exist — YAML manifests originate from **`roxctl central init-bundles generate`** output keyed by cluster label (**Deployments do not declare ACS enrollment annotations**).

Avoid **`istio.io/dataplane-mode: ambient`** on **`stackrox`** — ambient interception breaks Central ↔ PostgreSQL TLS (see topology table above).

## Capabilities used

- **CVE scanning** for images referenced by Industrial Edge and platform workloads.
- **Risk prioritization** across many namespaces and clusters.
- **Network and process baselines** optional hardening for regulated factories.

## Documentation

- [Red Hat Advanced Cluster Security for Kubernetes 4.10](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_security_for_kubernetes/4.10)

Chart paths: `charts/all/acs-operator` (hub central install), `charts/all/acs-secured-cluster` (spoke agents) when enabled.
