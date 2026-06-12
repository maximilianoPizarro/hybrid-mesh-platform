---
title: Getting Started (ACM-first)
weight: 2
---

# Getting Started (ACM-first)

This guide bootstraps the **hub** with one Helm install, registers **east** and **west** in ACM, and lets the **ApplicationSet** deploy spoke charts automatically. You do **not** run `helm install` on spokes.

## You'll have when finished

- [ ] **ACM** — `east` and `west` `ManagedCluster` Ready
- [ ] **Argo CD** — `east-spoke-components` / `west-spoke-components` from ApplicationSet
- [ ] **Industrial Edge** — sensors, MQTT, Kafka, line-dashboard on each spoke
- [ ] **Skupper** — hub `sitesInNetwork: 3`; listeners Ready in `service-interconnect`
- [ ] **Grafana / Kiali / Kafka Console** — hub fleet views
- [ ] **Developer Hub** — catalog + software templates
- [ ] **Dev Spaces** — CheCluster on east and west spokes (not hub)
- [ ] **Hybrid Mesh AI Workshop** (optional) — registration, Showroom, Plan B demos, NeuroFace

**Next:** [Scaffolding](scaffolding.md) for a new edge instance on east or west, **[Workshop](workshop/)** for Showroom userN lab, or **Camel CDC (Kaoto + Continue AI)** for a standalone route on the target spoke.

## Prerequisites

- OpenShift **4.14+** on hub + two spokes
- **Helm 3** and **`oc`** (cluster-admin on hub for ACM import)
- Fork of this repository; RHDP injects `deployer.domain` / `deployer.apiUrl` per cluster — see [RHDP field content](rhdp-field-content.md)

## Repository layout

```
charts/all/              → cross-cluster Helm components (shared)
charts/region/hub/       → hub clusterGroup + RHDP bootstrap
charts/region/east/      → east spoke clusterGroup + bootstrap
charts/region/west/      → west spoke clusterGroup + bootstrap
values-global.yaml       → pattern-wide globals
```

See [Region strategy](region-strategy.md) and [REGIONS.md](../../REGIONS.md).

---

## Phase 1: Prepare

1. Fork [`hybrid-mesh-platform`](https://github.com/maximilianoPizarro/hybrid-mesh-platform).
2. Set cluster domains via RHDP (`deployer.domain`, `clusters.hub.domain` on spokes) — see [`rhdp-field-content.md`](rhdp-field-content.md). **`fleet-values-sync`** patches most cross-cluster domains after ACM enrollment.
3. Validate rendering:

```bash
helm template test-hub charts/region/hub -f values-global.yaml \
  --set deployer.domain=apps.hub.example.com
helm template test-east charts/region/east -f values-global.yaml \
  --set deployer.domain=apps.east.example.com
helm template test-west charts/region/west -f values-global.yaml \
  --set deployer.domain=apps.west.example.com
```

---

## Phase 2: Bootstrap hub (RHDP or pattern.sh)

**RHDP (recommended):** catalog order with `gitops_repo_revision=main`, `gitops_repo_path=charts/region/hub`, `existing_gitops=true`.

**Local / manual:**

```bash
./pattern.sh install
# or TARGET_CLUSTERGROUP=hub ./pattern.sh install
```

This creates Application `hybrid-mesh-platform-hub`, which syncs hub workloads from `charts/region/hub/values.yaml` and `charts/all/*`.

---

## Phase 3: Register spokes (ACM + tokens)

1. Import **east** and **west** in ACM (UI or `ManagedCluster` + `auto-import-secret`).
2. Label clusters for placement:

```yaml
metadata:
  labels:
    cluster.open-cluster-management.io/clusterset: global
    region: east   # or west
```

3. Inject spoke API tokens on the hub (never commit) — RHDP/ACM auto-import usually suffices; **`fleet-values-sync`** can patch `field-content` when needed.

4. **ApplicationSet** `fleet-spoke-push` generates **`east-spoke-components`** and **`west-spoke-components`** on the **hub** only. PUSH apps deploy via `charts/all/spoke-meta-push`; each spoke's local Argo CD syncs PULL apps from **`charts/region/east|west/values.yaml`** — **no Helm install on spokes**. See **[GitOps deployment chain](gitops-deployment-chain.md)**.

```bash
# Hub — parent apps only
oc config use-context hub
oc get applications -n openshift-gitops | grep spoke-components

# East — child apps (example)
oc config use-context east
oc get applications -n openshift-gitops | grep -E 'east$'

# West — child apps (example)
oc config use-context west
oc get applications -n openshift-gitops | grep -E 'west$'
```

Do **not** expect `spoke-gateway-west` on the hub; it lives in **west** `openshift-gitops`.

5. **Skupper link (automatic):** after hub `service-interconnect` and spoke `spoke-interconnect` sync, the PostSync Job **`skupper-accesstoken-sync-hook`** reads `AccessGrant/spoke-link` status and creates `AccessToken/hub-link` on each spoke via **ManagedClusterAction** (no secrets in Git). A CronJob re-runs every 30 minutes (`*/30 * * * *`).

```bash
# Hub — verify grant + sync job
oc config use-context hub
oc get accessgrant spoke-link -n service-interconnect -o jsonpath='url={.status.url}{"\n"}'
oc logs job/skupper-accesstoken-sync-hook -n service-interconnect --tail=20

# Spoke — verify link (repeat per cluster)
oc config use-context east
oc get accesstoken,link -n service-interconnect
oc get site -n service-interconnect -o jsonpath='sitesInNetwork={.status.sitesInNetwork}{"\n"}'

# Hub — full VAN
oc config use-context hub
oc get site hub -n service-interconnect -o jsonpath='sitesInNetwork={.status.sitesInNetwork}{"\n"}'   # expect 3
```

Connection flow (grant server → AccessToken → Link → VAN): **[Service Interconnect → How the VAN connection works](service-interconnect.md#how-the-van-connection-works)**.

<details>
<summary>Manual AccessToken (fallback if ACM Job fails)</summary>

```bash
CODE=$(oc get accessgrant spoke-link -n service-interconnect -o jsonpath='{.status.code}')
URL=$(oc get accessgrant spoke-link -n service-interconnect -o jsonpath='{.status.url}')
CA=$(oc get accessgrant spoke-link -n service-interconnect -o jsonpath='{.status.ca}')
oc apply -f - <<EOF
apiVersion: skupper.io/v2alpha1
kind: AccessToken
metadata:
  name: hub-link
  namespace: service-interconnect
spec:
  code: ${CODE}
  url: ${URL}
  ca: |
$(echo "$CA" | sed 's/^/    /')
EOF
```

Use **`status.ca`** from the grant (SkupperGrantServerCA), not the OpenShift ingress CA.

</details>

If **`west-spoke-components`** is missing on the hub while placement includes west, refresh the ApplicationSet:

```bash
oc annotate applicationset fleet-spoke-push -n openshift-gitops argocd.argoproj.io/refresh=hard --overwrite
```

---

## Phase 4: Verify fleet

| Check | Command / UI |
| ----- | -------------- |
| ACM clusters | Console → **Infrastructure → Clusters** |
| Spoke app tree | ACM **Applications** or hub Argo CD |
| Skupper | `oc get listeners,connectors -n service-interconnect` (hub: `sitesInNetwork: 3`) |
| Industrial Edge | Route `industrial-edge.apps.<spoke-domain>` |
| Sync order | Spoke apps: wave 1 namespaces → 2 operators → **3 Camel Dashboard + mesh** → 5 edge → 6 interconnect |
| Camel Dashboard (spokes) | `oc get application camel-dashboard-openshift-all-east -n openshift-gitops` → Synced/Healthy; `oc get deploy -n camel-dashboard` |

---

## Phase 5: Enable features

### Camel Dashboard (east / west spokes)

Deployed from `charts/all/camel-dashboard-openshift` (vendored chart, wave **3**). Not installed on the hub.

1. Confirm parent apps exist on the hub: `east-spoke-components`, `west-spoke-components` (from ApplicationSet `fleet-spoke-push` after `field-content-acm-hub-spoke` sync).
2. On each spoke: `camel-dashboard-openshift-all-{east,west}` → **Synced** / **Healthy**.
3. **Cluster settings → Console** → enable plugin **camel-dashboard-console**.
4. Camel K `Integration` workloads (Industrial Edge) may not appear until registered as **CamelApp** CRs — see [Troubleshooting](troubleshooting.md).

Upgrade chart version: `./scripts/vendor-camel-dashboard-chart.sh <version>` then commit `charts/*.tgz`.

### Kiali multi-cluster (hub)

Default: `multiCluster.automateTokens: true` + spoke `exportTokenForHub: true`.

- Spoke PostSync writes **`kiali-hub-export`** ConfigMap.
- Hub CronJob writes **`kiali-remote-east`** / **`kiali-remote-west`**.
- If remote clusters show **Unauthorized**, delete legacy **`kiali-multi-cluster-secret`** and re-run token sync — see [Troubleshooting](troubleshooting.md).

### Kafka Console (hub)

Central UI for all Kafka clusters via Skupper bootstrap services. If `/api/kafkas` returns 404 on the external route, ensure **`apiRoute.enabled: true`** in `charts/all/kafka-console` (supplemental `/api` Route to the API container).

### Developer Hub OIDC

Keycloak realm `backstage` on `sso.<hub-domain>`. Set `keycloakOidcClientSecret` via `helm upgrade` (do not commit). See existing Keycloak steps in [Developer Hub](products/developer-hub.md).

### Continue AI (DevSpaces)

Create `continue-ai-config` Secret with MaaS API key after deploy (not in Git).

### Hybrid Mesh AI Workshop (hub)

Enabled by default in hub `values.yaml` (sync waves 4–7). Antora content: [showroom-hybrid-mesh-ai](https://github.com/maximilianoPizarro/showroom-hybrid-mesh-ai) (separate repo).

1. After hub sync, create ACS init bundle credentials (clusters empty in ACS UI until this runs):

```bash
oc create secret generic acs-init-credentials -n stackrox \
  --from-literal=ROX_ADMIN_PASSWORD='<central-admin-password>'
```

Re-sync Argo app `field-content-acs-init-bundle-sync`.

2. Verify workshop routes:

```bash
bash scripts/verify-workshop-e2e.sh
curl -sk -o /dev/null -w '%{http_code}\n' https://workshop-registration.apps.<hub-domain>/api/health
curl -sk -o /dev/null -w '%{http_code}\n' https://showroom-showroom.apps.<hub-domain>/
```

3. Facilitator test: register at `workshop-registration` → redirect Showroom with `USER_NAME=user1`; Developer Hub → System **`hybrid-mesh-shared-demos`**.

Detail: [Workshop docs](workshop/index.md) · Cursor skill **hybrid-mesh-ai-workshop** (`.cursor/skills/hybrid-mesh-ai-workshop/SKILL.md`).

---

## Phase 6: Day-two

- [Troubleshooting](troubleshooting.md) — ApplicationSet SSA, HBONE, Kiali tokens, Kafka Console API route
- [Architecture](architecture.md) — sync-wave reference
- [Deploy with ACM and GitOps](deploy-acm-gitops.md) — placement and GitOpsCluster detail
- **New spoke:** add `ManagedCluster`, label, copy `charts/region/east/values.yaml` pattern to a new region folder, extend ApplicationSet placement

---

## Quick reference: legacy nine-step map

| Old step | ACM-first phase |
| -------- | ----------------- |
| 1 Fork | Phase 1 |
| 2 Domains | Phase 1 |
| 3 Helm hub | Phase 2 |
| 4 ACM import | Phase 3 |
| 5 Argo cluster secrets | Phase 3 (tokens via `helm upgrade`) |
| 6 ApplicationSet | Phase 3–4 |
| 7 Kiali | Phase 5 |
| 8 Developer Hub | Phase 5 |
| 9 Continue AI | Phase 5 |

---

## Additional resources

- [Validation Guide](../validation-guide.md) — verify deployment is working
- [Bill of Materials](../bill-of-materials.md) — operator versions
- [Support Policy](../../SUPPORT.md) — community support

**Next →** [Scaffolding](scaffolding.md) · [Architecture](architecture.md) · [Troubleshooting](troubleshooting.md)
