---
title: RHDP install playbook
nav_order: 8
parent: Hybrid Mesh Platform
---

# RHDP install playbook

Lessons from fresh RHDP fleets (hub + east + west). This guide helps you reach **fleet value faster** — ACM inventory, fleet Grafana/Kafka Console, Developer Hub catalog, Industrial Edge via hub-gateway, and ACS Central — without fighting GitOps churn on day one.

## What “done” looks like (product outcomes)

| Outcome | Why it matters | How you know |
| ------- | -------------- | ------------ |
| **Fleet GitOps** | One hub controls PUSH operators + spoke PULL apps | `managedclusters` east/west Available; `fleet-spoke-push` ApplicationSet present |
| **Cross-cluster observability** | Hub sees east/west metrics and Kafka | Grafana + Kiali console links HTTP 200; Kafka Console lists clusters |
| **Secure fleet** | Central policy + spoke enforcement | ACS Central link 200; SecuredClusters join after hub domain sync |
| **Developer experience** | Scaffolding, catalog, workshop entry | Developer Hub link 200; `hybrid-mesh-shared-demos` in catalog |
| **Edge reachability** | Factory telemetry through one ingress | `industrial-edge.<hub-domain>` 200 after spokes + Skupper |
| **Private mesh** | Hub reaches spoke services without VPN | Skupper `sitesInNetwork: 3`; network-observer link 200 |

Run the platform smoke test from the hub:

```bash
oc login --token=... --server=<hub-api-url>
MIN_OK_CODE=200 bash scripts/verify-console-links.sh
bash scripts/verify-workshop-http200.sh   # console links + showroom/MCP/IE/spokes
bash scripts/verify-fleet.sh
```

Expect **60–90 minutes** after hub sync for all **19** hub console links to return HTTP 200 (operators, CRs, and routes converge gradually). Some links may show **503** while pods sync — that usually means the route exists but the backend is still starting. Full checklist: [Validation guide → Hub console links](../validation-guide.md#hub-console-links-19-expected).

---

## Recommended install order

### Option A — Hub first (fastest path to fleet value)

1. **Hub** — `charts/region/hub`, wait for `multiclusterhub` phase **Running** (~10–15 min).
2. **East / West** — `charts/region/east` and `charts/region/west` (parallel is fine).
3. **Import spokes** — auto-import via `managedClusters` values (see [Spoke auto-import](#spoke-auto-import-via-helm-values-acm-hub-spoke)) or ACM UI (see [Getting started → Phase 3](getting-started.md#phase-3-register-spokes-acm--tokens)).
4. **Sync domains** — trigger `fleet-values-sync` once (domains only; see below).
5. **Day-2 bootstrap** — automatic PostSync Jobs via Argo app `hub-post-install-bootstrap` (sync wave 9) when spokes are **Available**. Create facilitator secrets for ACS and MaaS — see [Post-install day-2](install-improvements.md#post-install-day-2-gitops-postsync-jobs).
6. **Verify** — console links + Skupper VAN (`sitesInNetwork: 3`).

### Option B — Three RHDP orders in parallel

Valid for catalog provisioning. Spokes may finish before the hub; cross-cluster features (Mailpit, ACS Central endpoint, hub-gateway Industrial Edge, console links to hub services) converge when ACM import and `fleet-values-sync` complete. Same **60–90 min** total; more time in a “partially connected” state.

---

## ACM bootstrap

**Symptom:** `acm-operator` retries `MultiClusterHub` because the CRD is not installed yet (Subscription still rolling out).

**Impact:** Delays ACM, ApplicationSet, and fleet PUSH — blocks the core product story.

**Mitigation (if Argo is stuck after ~15 min):**

```bash
helm template acm charts/all/acm-operator | oc apply -f -
```

Wait for MCH **Running** before importing spokes or enabling heavy `acm-hub-spoke` auto-sync with tokens.

---

## Spoke auto-import via Helm values (`acm-hub-spoke`)

The chart `charts/all/acm-hub-spoke` can **automatically import spoke clusters** into ACM when `managedClusters.{east,west}.apiUrl` and `.token` are provided in hub values. No manual ACM UI steps are needed.

### How it works

Setting `managedClusters.east.apiUrl` (and optionally `.token`) in the hub's Helm values triggers a sync-wave chain that registers and imports the spoke:

| Sync wave | Resource | Purpose |
| --------- | -------- | ------- |
| **0** | `ManagedCluster` | Registers the spoke with ACM (created first — ACM creates the cluster namespace) |
| **1** | `auto-import-secret` | One-time secret with spoke API URL + token; ACM klusterlet uses it to join, then ACM maintains the connection via its own certificates |
| **2** | `KlusterletAddonConfig` | Enables `application-manager`, `policyController`, `searchCollector`, etc. |
| **3** | `GitOpsCluster` | Binds ACM-managed clusters to Argo CD via `hub-spoke-placement` |
| **3** | `Placement` | Selects clusters with label `region: east` or `west` from ClusterSet `global` |
| **4** | `ApplicationSet fleet-spoke-push` | PUSH-based GitOps: creates `{name}-spoke-components` Application per matched cluster |

### Values needed

```yaml
managedClusters:
  east:
    apiUrl: https://api.cluster-<east-id>.dynamic2.redhatworkshops.io:6443
    token: sha256~...   # one-time import token (see below)
  west:
    apiUrl: https://api.cluster-<west-id>.dynamic2.redhatworkshops.io:6443
    token: sha256~...
```

- **`apiUrl`** gates everything — without it, no `ManagedCluster`, `auto-import-secret`, or `KlusterletAddonConfig` is rendered for that spoke.
- **`token`** is optional in the values; without it, `ManagedCluster` and `KlusterletAddonConfig` are still created, but you must import manually via ACM UI. With a token, the `auto-import-secret` enables fully automated import.
- **Tokens are one-time** — after the klusterlet agent joins, ACM maintains the connection using its own certificates. The token can be removed from values after import succeeds.

### Values chain (how managedClusters reaches the chart)

The hub region chart (`charts/region/hub/templates/clustergroup-application.yaml`) passes `managedClusters` from hub values into the clustergroup Application as `valuesObject.managedClusters`. The clustergroup then injects these values into child apps including `acm-hub-spoke`.

### Creating a spoke import token

Create a long-lived ServiceAccount token on the **spoke** cluster:

```bash
# On the spoke cluster (east or west)
oc create sa acm-auto-import -n kube-system
oc adm policy add-cluster-role-to-user cluster-admin -z acm-auto-import -n kube-system
oc create token acm-auto-import -n kube-system --duration=168h
```

The `--duration=168h` gives a 7-day window to complete the import. After klusterlet joins, the token is no longer needed.

### Patching the Application at runtime (without committing tokens to Git)

**Tokens must NOT be committed to Git.** Inject them at runtime by patching the Argo CD `Application` (or via RHDP `field-content` injection):

```bash
# Patch the hub's field-content Application with managed cluster credentials
oc patch application field-content -n openshift-gitops --type merge -p '
spec:
  source:
    helm:
      values: |
        managedClusters:
          east:
            apiUrl: "https://api.cluster-<east-id>.dynamic2.redhatworkshops.io:6443"
            token: "sha256~<east-token>"
          west:
            apiUrl: "https://api.cluster-<west-id>.dynamic2.redhatworkshops.io:6443"
            token: "sha256~<west-token>"
'
```

This flows through the clustergroup Application into `acm-hub-spoke`, which renders the `ManagedCluster` + `auto-import-secret` + `KlusterletAddonConfig` resources.

After spokes show **Available** in `oc get managedclusters`, remove the tokens from the Application patch (they are no longer needed):

```bash
oc patch application field-content -n openshift-gitops --type merge -p '
spec:
  source:
    helm:
      values: |
        managedClusters:
          east:
            apiUrl: "https://api.cluster-<east-id>.dynamic2.redhatworkshops.io:6443"
          west:
            apiUrl: "https://api.cluster-<west-id>.dynamic2.redhatworkshops.io:6443"
'
```

### Conditional rendering (fresh-install fix)

Since commit `26bf800`, `KlusterletAddonConfig` is guarded by `{{- if $cluster.apiUrl }}` — it only renders when an API URL is set. Previously, the config was always rendered, causing "namespace not found" errors on fresh installs where the spoke namespace did not yet exist.

### Verify import

```bash
oc get managedclusters                           # east/west should be Available
oc get klusterletaddonconfig -n east              # KlusterletAddonConfig present
oc get managedclusteraddon application-manager -n east   # addon active
oc get secrets -n openshift-gitops -l argocd.argoproj.io/secret-type=cluster  # Argo cluster secrets
oc get applicationset fleet-spoke-push -n openshift-gitops   # PUSH ApplicationSet present
```

---

## ACS SecuredCluster auto-configuration (hub vs spoke)

Chart `charts/all/acs-secured-cluster` automatically configures the `centralEndpoint` based on `clusterRole`:

- **Hub** (`clusterRole: hub`): `central.stackrox.svc:443` — in-cluster Central service
- **Spoke** (`clusterRole: spoke`): `central-stackrox.<hubClusterDomain>:443` — hub's Central route

The hub domain is resolved via the helper `acs-secured-cluster.hubClusterDomain`, which reads from `hubClusterDomain` → `global.hubClusterDomain` → `global.localClusterDomain` (with fallback). On spokes, `fleet-values-sync` or RHDP injection populates `clusters.hub.domain`, which propagates to `global.hubClusterDomain`.

Since commit `26bf800`, the `SecuredCluster` CR includes `SkipDryRunOnMissingResource=true` so it syncs cleanly on fresh installs before the ACS operator CRD is available.

---

## SkipDryRunOnMissingResource (fresh-install fixes)

On fresh cluster installs, CRDs from operators (ACM, ACS) may not exist when Argo CD first tries to sync resources that depend on them. Without `SkipDryRunOnMissingResource=true`, Argo's dry-run fails with "resource not found" and blocks sync.

The following charts include this annotation:

| Chart | Resource | Commit |
| ----- | -------- | ------ |
| `acm-operator` | `MultiClusterHub`, MCE `disable-proxy` | `cb6d924` |
| `acm-hub-spoke` | `KlusterletAddonConfig`, `GitOpsCluster`, `ApplicationSet fleet-spoke-push` | `26bf800` |
| `acs-operator` | `Central` CR | `26bf800` |
| `acs-secured-cluster` | `SecuredCluster` CR | `26bf800` |

This allows Argo CD to skip the server-side dry-run for these resources and apply them once the operator CRDs become available.

---

## Spoke tokens and `field-content`

**`fleet-values-sync` patches domains only** — not API tokens. Tokens belong in RHDP-injected secrets or a **one-time** hub patch.

**Anti-pattern:** Putting `managedClusters.east.token` / `west.token` in `field-content` while `acm-hub-spoke` auto-syncs can cause **east/west namespace terminate/recreate loops** if import fails.

**Preferred flow:**

1. MCH **Running**
2. Import east/west via auto-import (set `managedClusters.{east,west}.apiUrl` + `.token` — see [Spoke auto-import](#spoke-auto-import-via-helm-values-acm-hub-spoke)) or manually via ACM UI
3. Optional: patch domains via `fleet-values-sync` manual job
4. Re-enable automated sync on `acm-hub-spoke` once clusters are **Available**
5. Remove tokens from the Application patch (no longer needed after import)

**Manual ACM UI import:** Chart `acm-hub-spoke` still creates `KlusterletAddonConfig` for each `managedClusters` entry (east/west) even without `apiUrl`/`token` — required for `application-manager` and Argo cluster secrets (`east-spoke-components`). Verify:

```bash
oc get klusterletaddonconfig -n east
oc get managedclusteraddon application-manager -n east
oc get secrets -n openshift-gitops -l argocd.argoproj.io/secret-type=cluster
```

```bash
oc create job --from=cronjob/fleet-values-sync fleet-values-sync-manual -n openshift-gitops
```

---

## Argo CD + ACM 2.16

New installs include `acmArgocdOpenapiFix` in `charts/all/openshift-gitops` (PostSync Job + CronJob every 2 min): scales `ocm-proxyserver` to 0 and removes broken clusterview APIServices so hub apps report **Synced** instead of **Unknown**.

If apps show **ComparisonError** after MCH install and the CronJob is not yet applied:

```bash
helm template openshift-gitops charts/all/openshift-gitops | oc apply -f -
# or manual one-shot — see Troubleshooting
oc rollout restart statefulset openshift-gitops-application-controller -n openshift-gitops
```

**Note:** Local `helm install/upgrade` against the cluster may fail with the same clusterview schema error after ACM installs. Use `helm template | oc apply` for emergency fixes.

Full detail: [Troubleshooting → ArgoCD Unknown sync status](troubleshooting.md#argocd-unknown-sync-status-acm-216).

---

## OperatorGroups (RHODS, observability)

**Symptom:** CSV `Failed` — *csv created in namespace with multiple operatorgroups*.

**Impact:** No Grafana/Kiali (observability story) or OpenShift AI dashboard until fixed.

**Cause:** Duplicate OperatorGroups when both clustergroup **subscriptions** and `operatorGroup: true` on the same namespace create two OGs.

**Fix in Git:** Do not set `operatorGroup: true` on namespaces that already receive an OG from subscriptions (e.g. `redhat-ods-operator`). See `charts/region/hub/values.yaml`.

---

## GitLab (SCM for Developer Hub)

**v1.7.0** replaces GitLab with **GitLab Operator** (standard profile: webservice, gitaly, PostgreSQL, Container Registry) plus **GitLab Runner Operator** on the hub.

Chart: `charts/all/gitlab-operator/` — Subscriptions in `gitlab` and `gitlab-runner` namespaces (`installPlanApproval: Automatic`), `GitLab` CR (chart **9.11.6**) with bundled MinIO for object storage, plus Route `gitlab-apps` at `https://gitlab.apps.<hub-domain>/` (operator-created routes use `gitlab-gitlab.apps.*`; the extra Route matches console links and scaffolder URLs).

PostSync jobs:

- `gitlab-workshop-bootstrap` — groups `ws-user1` … `ws-userN`, `developer-hub`, `app-of-apps`, `workshop-demos`
- `gitlab-token-setup` (Developer Hub) — PAT → `GITLAB_TOKEN` in `developer-hub-oidc-auth`

**Hub sizing (workshop 30–50):** GitLab standard consumes **~20 GiB RAM** steady state; Kubecost adds **~14 GiB** (optional). Use **4 workers × 16 vCPU × 64 GiB** (64 vCPU / 256 GiB allocatable). The old **3×8×32** tier causes **Evicted** pods during sync (kubelet memory pressure). Minimum demo: **3×8×32** with Kubecost/CNV disabled.

**Spoke sizing (AI CV default, CPU):** **3×8×32** (24 vCPU / 96 GiB) for NeuroFace + OVMS ModelMesh + KServe YOLO PPE + DevSpaces. Minimum demo: **2×4×16** (8 vCPU / 32 GiB), no DevSpaces.

**Spoke sizing (GPU, optional):** add **1× NVIDIA T4/A10G per worker** for GPU-accelerated OVMS/YOLO or self-hosted vLLM 7B. Install **Node Feature Discovery** then **NVIDIA GPU Operator** before deploying InferenceServices with `nvidia.com/gpu` limits. Not included in pattern charts by default — see [Bill of Materials — GPU operators](../bill-of-materials.md#gpu-operators-optional).

Verify:

```bash
bash scripts/verify-node-capacity.sh
WORKSHOP_USERS=50 bash scripts/verify-node-capacity.sh
ROLE=spoke bash scripts/verify-node-capacity.sh
CHECK_GPU=1 ROLE=spoke bash scripts/verify-node-capacity.sh
```

**OpenShift AI 3.4:** subscription channel `stable-3.4`; dashboard URL `https://rh-ai.apps.<hub-domain>/`. Notebooks are **opt-in** (`notebook.deployCr: false`); PostSync scales `neuroface-ml-lab` StatefulSets to 0 until the AI module.

**RHODS subscription orphan (CSV missing, `UpgradePending`):** if `status.installedCSV` is set but `oc get csv` returns NotFound, delete the InstallPlan and Subscription in `redhat-ods-operator` and let Argo recreate (or re-sync `hybrid-mesh-platform-hub`):

```bash
oc delete installplan -n redhat-ods-operator --all
oc delete subscription rhods-operator -n redhat-ods-operator
```

---

## Kairos operator

Chart: `charts/all/kairos/` — community `kairos-operator` subscription only (no OperatorGroup in the chart; clustergroup creates **`kairos-system-operator-group`** via `kairos-system.operatorGroup: true` in `charts/region/*/values.yaml`).

`KairosAgent`, `KairosConsole`, and `SmartScalingPolicy` CRs use `SkipDryRunOnMissingResource` until the operator CSV installs.

**Symptom:** `Multiple OperatorGroup found in the same namespace` — duplicate OG from chart + clustergroup. **Fix in Git:** single OG from clustergroup only (chart ships subscription + CRs, not OperatorGroup).

---

## ACS Central (constrained hub CPU)

Central + Central DB default requests (~5.5 CPU) exceed small RHDP hub capacity when MaaS predictors, ODS notebooks, and NooBaa pods are scheduled.

**Chart:** `charts/all/acs-operator` — reduced Central/DB requests and scanner `maxReplicas: 1`.

**Day-2 (before expecting ACS console 200):**

```bash
oc annotate application hub-post-install-bootstrap -n openshift-gitops argocd.argoproj.io/refresh=hard --overwrite
# wait 60–120s; central-db must be Running 2/2
curl -skI "https://central-stackrox.$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}')/"
```

Relief scales MaaS predictors and `neuroface-ml-lab` notebooks to 0, trims duplicate ACS scanners, and pauses heavy NooBaa backing-store pods until Central DB schedules.

---

## Skupper network observer

Console link hostname: `skupper-network-observer-service-interconnect.<domain>`.

Use wrapper chart `charts/all/skupper-network-observer` (OCI subchart + OpenShift Route with **TLS passthrough** to port `https`). The subchart alone may land resources in `default`; the wrapper keeps everything in **`service-interconnect`**.

Observer pods need Skupper **Site** on the hub and TLS secrets from `certificates.skupper.io`.

---

## OpenShift AI (RHODS)

OperatorGroup in `redhat-ods-operator` must be **AllNamespaces** (`spec: {}`) — not `targetNamespaces: [redhat-ods-operator]` (CSV fails with `UnsupportedOperatorGroup`).

Chart includes `DSCInitialization` + `DataScienceCluster` with `defaultDeploymentMode: RawDeployment`.

Dashboard returns **403** without auth — `verify-console-links.sh` uses `oc whoami -t` when logged in.

---

## Kubecost

OperatorGroup name must match clustergroup convention: **`kubecost-operator-group`** (avoid duplicate OGs from chart + clustergroup).

Route uses `global.localClusterDomain` — not `apps.cluster.example.com`.

---

## Developer Hub

Backstage requires catalog ConfigMaps before the hub pod starts:

- `developer-hub-catalog-demos` (from `workshop-demos` chart, **sync wave 2** — before `developer-hub` wave 3)
- TechDocs ConfigMap keys must **not** contain `/` (OpenShift rejects `docs/index.md` as a key)

TechDocs mount path is separate from the IE catalog entity mount (`.../ie` vs `.../ie/techdocs`) so Backstage can load both.

Product check: `https://developer-hub.<hub-domain>` returns 200 and catalog shows **Industrial Edge** and **hybrid-mesh-shared-demos**.

---

## Vault console link

Upstream Vault chart creates `vault-link` pointing at the route root (HTTP **307**). For strict HTTP 200 checks, use **`/ui/`** in the href or patch post-install.

---

## Console links verification

```bash
oc login --token=...   # required for OAuth-protected links (OpenShift AI)
MIN_OK_CODE=200 bash scripts/verify-console-links.sh
```

| HTTP | Meaning |
| ---- | ------- |
| **200–399** | Route + backend OK — product surface reachable |
| **503** | Route exists; pods/operators still syncing (common in first hour) |
| **404 / 000** | Wrong hostname or no Route — check [Troubleshooting](troubleshooting.md) |

Script uses cluster bearer token when logged in; excludes operator-created duplicate `rhodslink` ConsoleLinks.

**Success criteria:** `Summary: 19 OK (200-399), 0 503 (route exists / pods down), 0 other` with exit code **0**.

---

## Industrial Edge dashboard (hub-gateway)

Hub **`hub-gateway`** uses **Istio Gateway API** (`Gateway` + `HTTPRoute`) → Skupper `ie-gateway-{east,west}` listeners. Requires:

1. **OSSM 3.2** installed on hub and spokes (`servicemeshoperator3` Subscription + `Istio`/`ZTunnel` CRs — sync wave **4**, before `hub-gateway` wave **5**)
2. **`fleet-values-sync`** populated `clusters.east.domain` / `clusters.west.domain` on hub
3. Skupper **`sitesInNetwork: 3`** (hub + east + west)
4. Spoke apps **`spoke-interconnect`** + **`spoke-gateway`** + **`industrial-edge-tst`** Healthy on each spoke
5. Listeners `ie-gateway-east|west` **Ready** (not *No matching connectors*)

```bash
bash scripts/verify-industrial-edge.sh
# optional: EAST_DOMAIN=apps.<east> WEST_DOMAIN=apps.<west> ...
```

Per-spoke direct check: `https://line-dashboard-industrial-edge-tst-all.<spoke-domain>/`

If Argo sync is **Unknown**, bootstrap mesh + Skupper manually:

```bash
oc annotate application hub-post-install-bootstrap -n openshift-gitops argocd.argoproj.io/refresh=hard --overwrite
```

---

## Grafana fleet metrics (East/West)

Hub dashboard **`platform-overview`** uses datasources `Prometheus-East` / `Prometheus-West` → Skupper listeners `prometheus-east|west`.

**No data on East/West panels** usually means:

- Skupper links incomplete (`sitesInNetwork` ≠ 3)
- Spoke **`spoke-interconnect`** missing `prometheus-{east,west}` Connector + `prometheus-auth-proxy`
- Hub listeners `prometheus-east|west` **Pending** (*No matching connectors*)
- ztunnel not Ready on ambient namespaces

```bash
oc get grafanadatasource -n openshift-cluster-observability-operator
oc get listener -n service-interconnect | grep prometheus
oc get ds -n ztunnel
```

Fix Skupper VAN first — same prerequisite as Industrial Edge.

---

## Skupper Network Observer (demo, sin auth)

Console link: `https://skupper-network-observer-service-interconnect.<hub-domain>/`

Chart `charts/all/skupper-network-observer` usa **`auth.strategy: none`** (sin basic auth en `/api/`). Solo para demos / RHDP — no usar en producción expuesta a Internet.

Si la consola pide usuario/contraseña, re-sincronizar la app o aplicar:

```bash
helm template skupper-network-observer charts/all/skupper-network-observer \
  --set global.localClusterDomain=apps.<hub-domain> \
  | oc apply -n service-interconnect -f -
```

---

## Service Mesh + Skupper bootstrap (spokes)

**Symptom:** `istiod` **Not found**, spoke `Gateway/spoke-gateway` stuck *Waiting for controller*, Skupper `sitesInNetwork=1`, IE **502/503**.

**Automated GitOps (default):**

| Layer | Mechanism |
| ----- | --------- |
| Operator | `servicemeshoperator3` Subscription (`stable-3.2`) in clustergroup subscriptions + `operators-edge` / `operators-platform` (PUSH) |
| Mesh CRs | App `servicemeshoperator3` (sync wave **4**) → `Istio`, `IstioCNI`, `ZTunnel`, ambient labels |
| Spoke ingress | App `spoke-gateway` (wave **6**) after istiod **Running** |
| Hub ingress | App `hub-gateway` (wave **5**) — Istio `Gateway` + `HTTPRoute` (no nginx fallback) |

**Cause chain when broken:**

1. **`servicemeshoperator3` Subscription** missing or mesh app synced before CSV installs
2. **`spoke-interconnect`** rendered with empty `clusterName` → invalid `Site/` and `Connector/ie-gateway-`
3. Skupper tokens never create `Link/hub-link` until spoke `Site` exists

**Mitigation** (after ManagedClusters **Available**):

```bash
oc annotate application hub-post-install-bootstrap -n openshift-gitops argocd.argoproj.io/refresh=hard --overwrite
```

Installs OSSM 3.2 (`stable-3.2`), applies `spoke-interconnect` + `spoke-gateway` + `industrial-edge-tst` on east/west, re-runs Skupper token sync, and validates IE + Prometheus paths.

**Verify:**

```bash
oc get pods -n istio-system -l app=istiod   # east/west
oc get site hub -n service-interconnect -o jsonpath='sitesInNetwork={.status.sitesInNetwork}{"\n"}'
bash scripts/verify-industrial-edge.sh
```

Expect **`sitesInNetwork=3`**, **istiod Running** on spokes, hub IE **200**, `prometheus-east|west` listeners **Ready**.

---

## Workshop users (`workshop-users` IdP)

Chart `platform-users` creates htpasswd users **`user1..userN`**, **`admin`**, **`platformadmin`** (default password `Welcome123!`).

- OAuth IdP name: **`workshop-users`** (secret `workshop-users` in `openshift-config`)
- **`grantClusterReader: true`** — Platform Hub-Spoke menu (ACM, Kiali, Skupper, Grafana links)
- Namespace **`view`** RoleBindings for middleware namespaces

Re-apply after rename:

```bash
oc apply -f scripts/fix-htpasswd-users-secret-job.yaml
oc wait --for=condition=complete job/htpasswd-users-secret-fix -n openshift-gitops --timeout=5m
```

Login: OpenShift console → **workshop-users** → `user1` / `Welcome123!`

---

## Workshop Showroom (Antora lab)

Hub apps **`workshop-registration`** (wave 4) and **`showroom`** (wave 5) live in namespace **`showroom`**. Entry from the console link **Hybrid Mesh AI Workshop** → registration → redirect to Antora with `USER_NAME=userN`.

| URL | Purpose |
| --- | ------- |
| `https://workshop-registration.<hub-domain>/` | Assign `userN`, progress tracking |
| `https://showroom-showroom.<hub-domain>/` | Lab guide + embedded terminal (`/terminal/`) |

**Symptom:** `showroom-showroom` returns **503** — Route missing or Argo never applied the `showroom` chart (common when sync status is **Unknown** on ACM 2.16 hubs).

**Mitigation** (after `fleet-values-sync` has east/west domains, or once ManagedClusters are **Available**):

```bash
oc logs -n openshift-gitops job/hub-post-install-workshop-surfaces
```

The script reads hub/east/west domains from the cluster, runs `helm template | oc apply`, and waits for the pod (Antora build init can take ~3 min).

**Verify:**

```bash
curl -sk -o /dev/null -w '%{http_code}\n' https://workshop-registration.apps.<hub-domain>/api/health
curl -sk -o /dev/null -w '%{http_code}\n' https://showroom-showroom.apps.<hub-domain>/
```

Expect **200** on both. Facilitator flow: register → Showroom with `?USER_NAME=user1` → Developer Hub catalog **`hybrid-mesh-shared-demos`**.

After pushing new Antora content to `showroom-hybrid-mesh-ai`:

```bash
bash scripts/sync-showroom-content.sh
# or: oc rollout restart deployment/showroom -n showroom
```

---

## Post-install day-2 (GitOps PostSync Jobs)

Day-2 automation is **in-cluster** — no facilitator shell scripts. Argo CD app **`hub-post-install-bootstrap`** (sync wave **9**) runs phased **PostSync Jobs** in `openshift-gitops`:

| Sync wave | Job | Purpose |
| --------- | --- | ------- |
| 10 | `hub-post-install-resource-relief` | Scale ODS/ACS/notebooks for tight hubs |
| 11 | `hub-post-install-fleet-mesh` | Hub mesh/gateway, refresh ApplicationSet, Skupper `sitesInNetwork=3` |
| 12 | `hub-post-install-workshop-surfaces` | Showroom, MCP, workshop-kuadrant-apis (+ Argo refresh) |
| 13 | `hub-post-install-istio-monitoring` | Hub PodMonitors + UWM |
| 14 | `hub-post-install-gitlab-bootstrap` | Re-trigger GitLab PostSync if route up |
| 15 | `hub-post-install-acs-init-bundle` | Re-trigger ACS bundles when `acs-init-credentials` exists |
| 16 | `hub-post-install-kuadrant-plans` | Sync APIProduct `discoveredPlans` |
| 17 | `hub-post-install-workshop-verify` | HTTP smoke (showroom, MCP, workshop-apis) |

**Wave 99:** `platform-validation` initial validation Job.

```bash
# Watch post-install Jobs (after hub Argo sync)
oc get jobs -n openshift-gitops | grep hub-post-install
oc logs -n openshift-gitops job/hub-post-install-fleet-mesh -f

# Re-run a phase: refresh the bootstrap app
oc annotate application hub-post-install-bootstrap -n openshift-gitops \
  argocd.argoproj.io/refresh=hard --overwrite
```

### Facilitator secrets (once per cluster — not in Git)

| Secret | Namespace | Keys | Triggers |
| ------ | --------- | ---- | -------- |
| `acs-init-credentials` | `stackrox` | `ROX_ADMIN_PASSWORD` | ACS PostSync jobs (wave 15 + `acs-init-bundle-sync`) |
| `maas-facilitator-seed` | `vault` | `api-key`, `granite-api-key`, `deepseek-api-key` (optional) | **Auto:** CronJob `maas-facilitator-rhdp-sync` reads RHDP `litemaas.apiKey` from `field-content`; PostSync `maas-facilitator-vault-seed` seeds Vault + ESO |

```bash
# ACS (before or after sync — Job skips until secret exists)
oc create secret generic acs-init-credentials -n stackrox \
  --from-literal=ROX_ADMIN_PASSWORD='...'

# MaaS — automatic when RHDP order has enable_litemaas_keys: true
oc get cronjob maas-facilitator-rhdp-sync -n vault
oc create job maas-facilitator-rhdp-sync-manual --from=cronjob/maas-facilitator-rhdp-sync -n vault
```

RHDP `litemaas.apiKey` in field-content propagates to Kuadrant/NeuroFace charts and **auto-creates** `maas-facilitator-seed` when `enable_litemaas_keys: true`.

### Manual steps (not automatable in Git)

1. **GitLab Operator** — approve pending **InstallPlan** in Console → Operators → GitLab.
2. **Showroom content** — push [showroom-hybrid-mesh-ai](https://github.com/maximilianoPizarro/showroom-hybrid-mesh-ai), then `bash scripts/sync-showroom-content.sh`.
3. **Console links verify** — `oc login --token=...` then `MIN_OK_CODE=200 bash scripts/verify-console-links.sh`.

---

## HashiCorp Vault (hub)

**Console:** Platform Hub-Spoke menu → **Vault** → `https://vault-vault.<hub-domain>/ui/` (use `/ui/` — route root returns HTTP 307).

**Workshop users:** `userN` has **view** on namespace `vault` (see `platform-users` chart).

**Facilitator init:** Vault chart is external VP `hashicorp-vault`. Create local `values-secret.yaml` (gitignored) for init/unseal — never commit tokens. External Secrets Operator (`openshift-external-secrets`) connects ESO to Vault when configured.

**Demo login (userpass):** chart `vault-demo-auth` creates workshop users for the UI. Same password as OpenShift workshop users (`Welcome123!` by default).

| Vault user | Password (demo) | Policy |
|------------|-----------------|--------|
| `admin` | `Welcome123!` | read/write `secret/workshop/*`, read `secret/global/*` |
| `user1` | `Welcome123!` | read `secret/workshop/*` |

Vault UI → **Sign in** → method **Username** (`userpass`) → `admin` / `Welcome123!`.

Re-apply: sync Argo app `vault-demo-auth` (PostSync Job `vault-demo-auth-hook`)

```bash
oc get route -n vault
oc get pods -n vault
oc get cm vault-demo-login -n vault -o yaml
```

**Vault + ESO (hub):** PostSync Job `maas-facilitator-vault-seed` runs when Secret `maas-facilitator-seed` exists in namespace `vault` (see [Vault product page](products/vault.md)).

---

## MaaS API keys (Lightspeed, NeuroFace, OpenShift AI)

Never commit `sk-*` keys. RHDP `litemaas.apiKey` or facilitator Secret:

```bash
oc create secret generic maas-facilitator-seed -n vault \
  --from-literal=api-key='sk-...' \
  --from-literal=granite-api-key='sk-...' \
  --from-literal=deepseek-api-key='sk-...'
oc annotate application vault-maas-external-secrets -n openshift-gitops \
  argocd.argoproj.io/refresh=hard --overwrite
```

| Secret (K8s, from ESO) | Namespace | Vault key | Consumers |
|--------|-----------|-----------|-----------|
| `kairos-ai-credentials` | `kairos-system` | `api-key` | Kairos (llama-scout-17b) |
| `openshift-ai-maas-credentials` | `maas-workshop` | all three + `OPENAI_API_BASE` | ODS playground / ISV proxies |
| `neuroface-maas-api-key` | `neuroface` | `api-key` | NeuroFace chat |
| `llama-stack-secrets` | `developer-hub` | `granite-api-key` → `VLLM_API_KEY` | Lightspeed |
| `ai-maas-upstream-credentials` | `ai-gateway-system` | `granite-api-key` | Kuadrant AI gateway AuthPolicy |

**Symptom:** Developer Hub `/lightspeed` or NeuroFace chat **401** — create `maas-facilitator-seed` in `vault` and refresh `vault-maas-external-secrets`.

**Symptom:** `ClusterSecretStore vault-workshop-maas` not ready / ExternalSecret `SecretSyncedError` with *permission denied* on `auth/kubernetes/login` — the Vault kubernetes auth **reviewer JWT expires**. Chart `vault-maas-external-secrets` runs CronJob `vault-k8s-auth-eso-refresh` every **15 min** (regular Argo resource, not PostSync-only). Day-2 job `hub-post-install-vault-maas-eso` applies the chart and triggers a manual refresh.

```bash
oc create job vault-k8s-auth-manual --from=cronjob/vault-k8s-auth-eso-refresh -n vault
oc rollout restart deployment/external-secrets -n external-secrets
```

**Symptom:** NetworkPolicy — OpenShift ESO blocks Vault `:8200`; chart applies `allow-vault-maas-egress-8200`.

### RHDP `unsealvault-cronjob` pods in `Init:Error` (namespace `imperative`)

These pods belong to the **RHDP imperative** operator, not chart `vault-maas-external-secrets`. On first hub install they often fail when ACM spokes are not imported yet (`vault_spokes_init.yaml`) or when the playbook races Vault permissions (`403` on `sys/mounts/secret`). **Vault stays unsealed** if already initialized; the CronJob retries every 5 min and recent runs should show **Completed**.

```bash
# Safe cleanup of stale failed pods (does not delete Vault)
oc delete pod -n imperative -l job-name --field-selector=status.phase=Failed
oc delete job -n imperative -l job-name --field-selector=status.successful=0
```

Ignore `Init:Error` rows older than the latest **Completed** `unsealvault-cronjob-*` job unless `vault-0` is Sealed (`oc exec -n vault vault-0 -- vault status`).

RHDP can inject `litemaas.apiKey` into clustergroup values (wired to `workshop-kuadrant-apis`, `openshift-ai-hub`, `neuroface` charts).

---

## Workshop APIs (Kuadrant / Connectivity Link)

Public APIs via **ExternalName** + Istio **ServiceEntry** → hub **Gateway API** → Kuadrant **APIProduct** (auto-approval).

| URL | Purpose |
|-----|---------|
| `https://workshop-apis.<hub-domain>/httpbin/*` | httpbin (PlanPolicy bronze/silver/gold) |
| `https://workshop-apis.<hub-domain>/countries/*` | REST Countries |
| `https://workshop-apis.<hub-domain>/mcp` | MCP Gateway (Kuadrant API key) |
| `https://ai-gateway.<hub-domain>/v1/chat/completions` | MaaS LLM (TokenRateLimit free/gold) |

**Developer Hub:** `/kuadrant` → API Products → click product **name** → **Request API key** (auto-approved) → **My API Keys** → `Authorization: APIKEY …`. Or **Catalog** → API entity → **Kuadrant** tab.

**Fresh install:** Catalog ConfigMaps use piped Helm `replace` (not `$var = replace`, which truncates file content). After sync, confirm `developer-hub-catalog-workshop-kuadrant-apis` contains API entities before opening the UI.

**Kuadrant catalog sync:** APIProduct CRs need `backstage.io/owner: group:default/platform-engineering` (chart `workshop-kuadrant-apis`) so the Kuadrant provider registers entities. Static catalog entities live under System **workshop-kuadrant-apis**. Login via Keycloak (`user1` / `Welcome123!` or `platformadmin` to edit products).

**OpenShift Console:** RHCL console plugin — AuthPolicy / PlanPolicy in `workshop-kuadrant-apis` and `ai-gateway-system`; APIProducts in same namespaces.

**RHCL + mesh order:** `rhcl-operator` syncWave `1`, `hub-gateway` / mesh syncWave `5`, `workshop-kuadrant-apis` syncWave `6`. If policies stay **Not Accepted**, verify `ISTIO_GATEWAY_CONTROLLER_NAMES` on the Kuadrant operator deployment and restart the pod (see [Connectivity Link](products/connectivity-link.md#rhcl--sailistio-mesh-required)).

```bash
oc annotate application hub-post-install-bootstrap -n openshift-gitops argocd.argoproj.io/refresh=hard --overwrite
curl -sk -o /dev/null -w '%{http_code}\n' https://workshop-apis.<hub-domain>/httpbin/get
# Expect 401 without key
```

Catalog: System **workshop-kuadrant-apis** — Components + API entities for userN onboarding.

---

## MCP Gateway

Console link: `https://mcp-gateway.<hub-domain>/mcp` (expect **HTTP 200** on `/mcp`).

When Argo app `mcp-gateway` stays **Unknown** and the route returns **503**:

```bash
oc logs -n openshift-gitops job/hub-post-install-workshop-surfaces
```

Requires hub OpenShift AI / Lightspeed stack for MCPServerRegistration backends.

---

## Kafka + Camel MQTT (spokes)

**Symptom:** `mqtt-to-kafka` Integration Error; Kafka metadata timeout; no messages on topic `temperature`.

**Fix chain (Git + day-2):**

1. **`clusterName`** in spoke values — `charts/region/east|west/values.yaml` overrides for `industrial-edge-tst`, `stormshift`, `industrial-edge-data-lake` (avoids empty broker DNS `broker-0-.`).
2. **Kafka advertised host** — Strimzi `advertisedHost` needs matching **EndpointSlice** on hub (`*-kafka-brokers-advertised`); see [Troubleshooting → Kafka advertised DNS](troubleshooting.md#kafka-advertised-dns-endpointslice).
3. **Istio ambient + Camel K** — trait **`deployment`** with `istio.io/dataplane-mode: none` on `mqtt-to-kafka` (trait `pod` is ignored in Camel K 2.10).
4. **Registry 401** — refresh `camel-k-registry-docker`, delete Integration + IntegrationKit, re-sync app.

```bash
oc get integration mqtt-to-kafka -n industrial-edge-tst-all -o jsonpath='{.status.phase}{"\n"}'
# Expect Running
```

---

## OpenShift Virtualization (CNV)

Hub-only. Chart `cnv-example` installs Subscription + HyperConverged + demo VM in **`cnv-workshop`**.

Requires nested virtualization on workers (may be unavailable on some RHDP cloud flavors).

```bash
oc get csv -n openshift-cnv | grep kubevirt
oc get vm -n cnv-workshop
```

---

## Related docs

- [Getting started](getting-started.md) — ACM-first install phases
- [RHDP field content](rhdp-field-content.md) — catalog parameters
- [Validation guide](../validation-guide.md) — component matrix
- [Troubleshooting](troubleshooting.md) — symptom matrix
