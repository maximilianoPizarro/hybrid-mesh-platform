---
title: RHDP install playbook
weight: 7
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
bash scripts/verify-fleet.sh
```

Expect **60–90 minutes** after hub sync for all **19** hub console links to return HTTP 200 (operators, CRs, and routes converge gradually). Some links may show **503** while pods sync — that usually means the route exists but the backend is still starting. Full checklist: [Validation guide → Hub console links](../validation-guide.md#hub-console-links-19-expected).

---

## Recommended install order

### Option A — Hub first (fastest path to fleet value)

1. **Hub** — `charts/region/hub`, wait for `multiclusterhub` phase **Running** (~10–15 min).
2. **East / West** — `charts/region/east` and `charts/region/west` (parallel is fine).
3. **Import spokes** — ACM UI or `auto-import-secret` (see [Getting started → Phase 3](getting-started.md#phase-3-register-spokes-acm--tokens)).
4. **Sync domains** — trigger `fleet-values-sync` once (domains only; see below).
5. **Verify** — console links + Skupper VAN (`sitesInNetwork: 3`).

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

## Spoke tokens and `field-content`

**`fleet-values-sync` patches domains only** — not API tokens. Tokens belong in RHDP-injected secrets or a **one-time** hub patch.

**Anti-pattern:** Putting `managedClusters.east.token` / `west.token` in `field-content` while `acm-hub-spoke` auto-syncs can cause **east/west namespace terminate/recreate loops** if import fails.

**Preferred flow:**

1. MCH **Running**
2. Import east/west (ACM UI, or **`ManagedCluster` first** then `auto-import-secret` — see chart `acm-hub-spoke`; do **not** pre-create a `Namespace` with `cluster.open-cluster-management.io/managedCluster` label)
3. Optional: patch domains via `fleet-values-sync` manual job
4. Re-enable automated sync on `acm-hub-spoke` once clusters are **Available**

```bash
oc create job --from=cronjob/fleet-values-sync fleet-values-sync-manual -n openshift-gitops
```

---

## Argo CD + ACM 2.16

New installs include `resourceExclusions` for `clusterview.open-cluster-management.io` in the `openshift-gitops` chart — avoids blocking sync on fresh hubs.

If apps show **ComparisonError** after MCH install:

```bash
# Apply chart or patch ArgoCD — see Troubleshooting
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

## Gitea (SCM for Developer Hub)

The upstream Gitea chart’s PostgreSQL/Valkey pods need **`privileged` SCC** on OpenShift (not `anyuid` — upstream sets seccomp annotations that `anyuid` rejects).

Chart binding: `charts/all/gitea/templates/clusterrolebinding-gitea-privileged.yaml`.

Route must target Service **`gitea-http`** (not `field-content-gitea-chart-http`).

Without Gitea, Developer Hub scaffolding and local SCM integration are degraded — the **Gitea console link** stays 503.

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

- `developer-hub-catalog-demos` (from `workshop-demos` chart)
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

## Related docs

- [Getting started](getting-started.md) — ACM-first install phases
- [RHDP field content](rhdp-field-content.md) — catalog parameters
- [Validation guide](../validation-guide.md) — component matrix
- [Troubleshooting](troubleshooting.md) — symptom matrix
