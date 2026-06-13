# Hybrid Mesh Platform - Overview Skill

## Pattern Overview

Hub-spoke multi-cluster GitOps on OpenShift (Validated Patterns, Sandbox tier). Fork of multicloud-gitops with **region paths** (`charts/region/{hub,east,west}`) and **50+ charts** under `charts/all/`.

**Problem it solves:** secure multi-cluster connectivity (Skupper VAN), centralized fleet GitOps (ACM + dual PUSH/PULL), Industrial Edge on spokes, hub-resident AI/security/observability.

## Repository Structure

```
hybrid-mesh-platform/
├── charts/
│   ├── region/
│   │   ├── hub/          # Bootstrap → hybrid-mesh-platform-hub (clustergroup)
│   │   ├── east/         # East spoke bootstrap + clusterGroup values
│   │   └── west/         # West spoke bootstrap + clusterGroup values
│   └── all/              # 50+ shared Helm charts
├── docs/
│   ├── validatedpatterns-docs/   # VP / GitHub Pages content
│   └── index.md                    # Public docs index
├── scripts/
│   ├── verify-console-links.sh     # curl all ConsoleLink hrefs
│   ├── verify-workshop-http200.sh  # console links + workshop/AI strict 200
│   ├── apply-post-install-day2.sh  # day-2 bootstrap (mesh, showroom, MCP)
│   ├── apply-fleet-mesh.sh
│   ├── apply-workshop-showroom.sh
│   ├── apply-mcp-gateway.sh
│   ├── verify-fleet.sh
│   ├── sync-showroom-content.sh          # PNGs → showroom-hybrid-mesh-ai
│   ├── workshop-screenshot-manifest.yaml # live hub URL per hero
│   └── capture-workshop-screenshots.mjs  # Playwright batch (skips preserve)
└── values-global.yaml
```

## Product outcomes (definition of "done")

Validate **what the platform delivers**, not only Argo CD sync status:

| Outcome | How you know |
| ------- | ------------ |
| Fleet GitOps | `managedclusters` east/west **Available**; `fleet-spoke-push` ApplicationSet present |
| Cross-cluster observability | Grafana + Kiali + Kafka Console console links HTTP 200 |
| Secure fleet | ACS Central link 200; SecuredClusters on spokes |
| Developer experience | Developer Hub 200; catalog shows IE + `hybrid-mesh-shared-demos` |
| Edge reachability | `industrial-edge.<hub-domain>` 200 after spokes + Skupper |
| Private mesh | Skupper `sitesInNetwork: 3` on hub site |

Smoke test (hub):

```bash
oc login --token=<token> --server=<hub-api-url>
MIN_OK_CODE=200 bash scripts/verify-console-links.sh   # expect 19 OK, exit 0
bash scripts/verify-workshop-http200.sh                # workshop + MCP + spokes
bash scripts/verify-fleet.sh
```

Allow **60–90 min** after hub sync; **503** often means route exists but backend still starting.

**RHDP playbook:** `docs/validatedpatterns-docs/install-improvements.md`

## Bootstrap chain (end-to-end)

1. **RHDP** or `./pattern.sh make install` deploys `charts/region/{hub,east,west}`.
2. Region chart creates Argo CD Application **`hybrid-mesh-platform-{region}`** (VP **clustergroup** multisource).
3. Clustergroup loops `clusterGroup.applications` in `charts/region/{region}/values.yaml` → child apps (`acm-hub-spoke`, `developer-hub`, …).
4. **`acm-hub-spoke`** creates ApplicationSet **`fleet-spoke-push`** → `east-spoke-components` / `west-spoke-components` (PUSH).
5. Each spoke's local Argo CD syncs PULL apps from `charts/region/east|west/values.yaml`.

Legacy names (`field-content-acm-hub-spoke`, `connectivityLink.apps[]`) are obsolete — use app names from clustergroup values.

**Full walkthrough:** `docs/validatedpatterns-docs/gitops-deployment-chain.md`

## Cluster Roles

| Role | Path | Key components |
|------|------|----------------|
| **Hub** | `charts/region/hub` | ACM, Developer Hub, ACS Central, Skupper listeners, Grafana, Kafka Console, RHCL hub-gateway |
| **East/West** | `charts/region/east\|west` | Industrial Edge, ACS Secured, Skupper connectors, spoke-gateway, ambient mesh |

## GitOps Strategy

| Strategy | Mechanism | Charts (examples) |
|----------|-----------|-------------------|
| **PUSH** | Hub ApplicationSet `fleet-spoke-push` | `operators-ci`, `operators-platform` via `spoke-meta-push` |
| **PULL** | Spoke clustergroup / managedClusterGroups | IE stack, mesh, observability, `operators-edge` |

See `docs/validatedpatterns-docs/gitops-push-vs-pull.md`.

## Domain injection

| Source | Keys |
|--------|------|
| RHDP per cluster | `deployer.domain`, `deployer.apiUrl` via Argo `helm.values` (never `{{ }}` in Git) |
| Spoke → hub refs | `clusters.hub.domain` (auto via **`fleet-values-sync`** CronJob after ACM import) |
| Clustergroup globals | `global.localClusterDomain`, `global.hubClusterDomain` |

**`fleet-values-sync` patches domains only — not API tokens.** Tokens belong in RHDP secrets or one-time ACM import. **Anti-pattern:** `managedClusters.*.token` in auto-syncing `field-content` while `acm-hub-spoke` syncs → east/west namespace terminate/recreate loops.

**Never** put `{{ openshift_cluster_ingress_domain }}` in Git-tracked YAML — Helm treats `{{ }}` as template syntax.

## Console Links (`charts/all/console-links`)

- **syncWave:** `10` on hub (after routes exist).
- **Domains:** `$domain` = local cluster; `$hubDomain` = hub apps domain (spokes link to hub services).
- **Hub-only block:** ACM, Kairos, Skupper observer, NeuroFace, workshop, etc.

### ConsoleLink hostname conventions (must match Routes)

| Link | Host pattern | Notes |
|------|--------------|-------|
| Skupper Network Observer | `skupper-network-observer-service-interconnect.<domain>` | Wrapper chart `charts/all/skupper-network-observer` (OCI subchart + Route **TLS passthrough** → port `https`). Deploy to **`service-interconnect`**, not `default` |
| NeuroFace | `neuroface.<domain>` | Requires clustergroup override `neuroface.route.host` — default subchart Route is `neuroface-neuroface.<domain>` |
| Kafka Console | `kafka-console.<domain>` | Console CR `spec.hostname` |
| Industrial Edge (hub GW) | `industrial-edge.<hubDomain>` | `charts/all/hub-gateway` — link 200 when Route exists; full factory UI needs spoke Skupper connectors + mesh |
| Gitea | `gitea-gitea.<domain>` | **`privileged` SCC**; Route → **`gitea-http`** |
| OpenShift AI | `rhods-dashboard-redhat-ods-applications.<domain>` | AllNamespaces OG; bearer token for verify |
| Kubecost | `kubecost.<domain>` | OG **`kubecost-operator-group`** |
| Vault | `vault.<domain>/ui/` | Root route returns 307 |
| Workshop login | OAuth IdP **`workshop-users`** | `platform-users` chart; `grantClusterReader: true` for console middleware menu |

Verify:

```bash
oc login --token=<token> --server=<hub-api-url>
MIN_OK_CODE=200 bash scripts/verify-console-links.sh
bash scripts/verify-industrial-edge.sh   # IE dashboard chain
```

## Key Files

| File | Purpose |
|------|---------|
| `charts/region/hub/values.yaml` | Hub apps, sync waves, neuroface/skupper overrides |
| `charts/all/acm-hub-spoke/` | Placement, ApplicationSet `fleet-spoke-push`, GitOpsCluster |
| `charts/all/openshift-gitops/templates/argocd.yaml` | ArgoCD CR + ACM 2.16 resourceExclusions |
| `charts/all/acm-operator/` | ACM subscription + MCE `cluster-proxy-addon: false` automation |
| `charts/all/gitea/` | Gitea + `clusterrolebinding-gitea-privileged.yaml` + Route → `gitea-http` |
| `charts/all/skupper-network-observer/` | OCI network-observer wrapper + passthrough Route |
| `charts/all/openshift-ai-hub/` | DSCInitialization, DataScienceCluster RawDeployment |
| `charts/all/console-links/templates/all.yaml` | ConsoleLink hrefs |
| `charts/all/fleet-values-sync/` | Cross-cluster domain patching (works even when Argo sync Unknown) |
| `values-global.yaml` | Pattern-wide globals |

## Documentation map

| Topic | Path |
|-------|------|
| Architecture + diagrams | `docs/validatedpatterns-docs/architecture.md` |
| Getting started | `docs/validatedpatterns-docs/getting-started.md` |
| **RHDP install playbook** | `docs/validatedpatterns-docs/install-improvements.md` |
| RHDP 3 orders | `docs/validatedpatterns-docs/rhdp-field-content.md` |
| GitOps chain | `docs/validatedpatterns-docs/gitops-deployment-chain.md` |
| Product value (ACM, Skupper, RHCL, …) | `docs/validatedpatterns-docs/products/` |
| Troubleshooting | `docs/validatedpatterns-docs/troubleshooting.md` |
| **Workshop Showroom** | `docs/validatedpatterns-docs/workshop/index.md` |
| Showroom content skill | `showroom-hybrid-mesh-ai/.cursor/skills/hybrid-mesh-ai-workshop/SKILL.md` |
| Docs index | `docs/validatedpatterns-docs/README.md` |

## Common Operations

```bash
# Fleet
oc get managedclusters
oc get applicationset fleet-spoke-push -n openshift-gitops

# Day-2 bootstrap (after RHDP install + ACM import)
bash scripts/apply-post-install-day2.sh

# Force refresh one app
oc annotate application <app-name> -n openshift-gitops argocd.argoproj.io/refresh=hard --overwrite

# Console links HTTP check
MIN_OK_CODE=200 bash scripts/verify-console-links.sh
bash scripts/verify-workshop-http200.sh
```

## Known Issues

### ACM operator bootstrap (fresh RHDP hub)

**Symptom:** `acm-operator` retries `MultiClusterHub` — CRD not installed yet.

**Mitigation (after ~15 min stuck):**

```bash
helm template acm charts/all/acm-operator | oc apply -f -
```

Wait for MCH **Running** before importing spokes.

### Duplicate OperatorGroups (RHODS, observability, Kubecost, Kairos)

**Symptom:** CSV `Failed` — *multiple operatorgroups* or `UnsupportedOperatorGroup`.

**Cause:** `operatorGroup: true` on a namespace that already gets an OG from clustergroup subscriptions (e.g. `redhat-ods-operator`), or duplicate OG names in chart + clustergroup (Kubecost, Kairos).

**Fix:** Remove duplicate `operatorGroup: true` in `charts/region/hub/values.yaml`. RHODS OG must be **AllNamespaces** (`spec: {}`). Kubecost OG: **`kubecost-operator-group`**.

### Developer Hub prerequisites

- ConfigMap `developer-hub-catalog-demos` (from `workshop-demos`) before Backstage starts
- TechDocs ConfigMap keys must **not** contain `/` (OpenShift rejects `docs/index.md` as key)
- Separate mounts: IE catalog `.../ie` vs techdocs `.../ie/techdocs`

### Skupper network observer

Use wrapper **`charts/all/skupper-network-observer`** (OCI subchart + OpenShift Route TLS **passthrough** to port `https`). Deploy into **`service-interconnect`** (not `default`). Needs hub Skupper Site + TLS secrets from `certificates.skupper.io`.

### ACM spoke import order

**Never** pre-create a `Namespace` with `cluster.open-cluster-management.io/managedCluster` label before the `ManagedCluster` CR — OpenShift terminates the namespace in a loop. Chart `acm-hub-spoke` creates **`ManagedCluster` first**; ACM creates the cluster namespace. During manual import, consider disabling auto-sync/prune on `acm-hub-spoke` until clusters are **Available**.

### ACM 2.16 + ArgoCD "Unknown" (critical on existing hubs)

**Error:** `SchemaError(... clusterview/v1alpha1.UserPermission.status)`

| Scenario | Behavior |
|----------|----------|
| **New install** | `charts/all/openshift-gitops` ships `resourceExclusions` for `clusterview.open-cluster-management.io` and `internal.open-cluster-management.io` — should avoid the bug |
| **Already-deployed hub** | Exclusions in Git/CR often **do not** unblock sync — controller still fails OpenAPI schema load. Force sync, APIService delete, Redis flush, proxy addon disable **did not** fix live hub |
| **Recovery** | Hub reinstall with fixed chart, or ACM/ArgoCD upgrade when available |

Do **not** assume "Unknown = cosmetic" on a hub that shows all apps Unknown — verify with `oc get application <app> -o jsonpath='{.status.operationState.phase}'` and whether Routes/pods exist.

### MaaS model alias

Workshop default `llama-scout-17b` is RHDP MaaS alias; upstream model is `meta-llama/Llama-Scout-17B-16E-Instruct`.

## External links

- GitHub Pages: https://maximilianopizarro.github.io/hybrid-mesh-platform/
- Bill of Materials: `docs/bill-of-materials.md`
