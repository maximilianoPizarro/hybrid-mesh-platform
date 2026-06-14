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
bash scripts/verify-workshop-http200.sh   # console links + showroom/MCP/IE/spokes
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
5. **Day-2 bootstrap** — when spokes are **Available**, run `bash scripts/apply-post-install-day2.sh` (mesh, showroom, MCP gateway, HTTP 200 gate).
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
bash scripts/apply-fleet-mesh.sh
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
bash scripts/apply-fleet-mesh.sh
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
bash scripts/apply-workshop-showroom.sh
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

## Post-install day-2 (automated)

When ACM import and `fleet-values-sync` are done but Argo CD shows **Unknown** sync (ACM 2.16), run one script from the hub:

```bash
export KUBECONFIG=/tmp/hub-kubeconfig   # or oc login
bash scripts/apply-post-install-day2.sh
```

| Step | Script | What it fixes |
| ---- | ------ | ------------- |
| Fleet mesh + Skupper | `apply-fleet-mesh.sh` | OSSM 3.2, spoke-interconnect, IE listeners, `sitesInNetwork=3` |
| Workshop showroom | `apply-workshop-showroom.sh` | Registration + Antora pod when `showroom` app never synced |
| MCP Gateway | `apply-mcp-gateway.sh` | CRDs + MCPServerRegistration when `/mcp` returns 503 |
| Istio/Kafka monitoring | `apply-istio-monitoring.sh` | PodMonitors + UWM on hub/spokes (Grafana panels) |
| Kuadrant public APIs | `apply-workshop-kuadrant-apis.sh` | workshop-apis gateway + APIProducts |
| MaaS secrets | `apply-maas-secrets.sh` | Lightspeed / NeuroFace / ODS keys (env vars, optional) |
| HTTP 200 gate | `verify-workshop-http200.sh` | 19 console links + workshop/AI URLs |

Skip mesh if already healthy: `SKIP_MESH=1 bash scripts/apply-post-install-day2.sh`.

---

## HashiCorp Vault (hub)

**Console:** Platform Hub-Spoke menu → **Vault** → `https://vault-vault.<hub-domain>/ui/` (use `/ui/` — route root returns HTTP 307).

**Workshop users:** `userN` has **view** on namespace `vault` (see `platform-users` chart).

**Facilitator init:** Vault chart is external VP `hashicorp-vault`. Create local `values-secret.yaml` (gitignored) for init/unseal — never commit tokens. External Secrets Operator (`openshift-external-secrets`) connects ESO to Vault when configured.

```bash
oc get route -n vault
oc get pods -n vault
```

Future: model keys via Vault paths + `ExternalSecret` (today: `scripts/apply-maas-secrets.sh`).

---

## MaaS API keys (Lightspeed, NeuroFace, OpenShift AI)

Never commit `sk-*` keys. Inject after hub sync:

```bash
export MAAS_KEY_LLAMA='sk-...'
export MAAS_KEY_GRANITE='sk-...'   # optional — Lightspeed default model
export MAAS_KEY_DEEPSEEK='sk-...'  # optional
bash scripts/apply-maas-secrets.sh
```

| Secret | Namespace | Consumers |
|--------|-----------|-----------|
| `kairos-ai-credentials` | `kairos-system` | Kairos, Lightspeed sync |
| `openshift-ai-maas-credentials` | `maas-workshop` | ODS playground, MaaS proxies |
| `neuroface-maas-api-key` | `neuroface` | NeuroFace `/api/chat` |
| `maas-granite-credentials` | `maas-workshop` | ODS connection (optional) |

**Symptom:** Developer Hub `/lightspeed` or NeuroFace chat **401** — run `apply-maas-secrets.sh` and restart `developer-hub` / `neuroface`.

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

**Developer Hub:** `/kuadrant` → API Products → Request key (auto-approved) → **My API Keys** → `Authorization: APIKEY …`

**OpenShift Console:** RHCL console plugin — AuthPolicy / PlanPolicy in `workshop-kuadrant-apis` and `ai-gateway-system`; APIProducts in same namespaces.

**RHCL + mesh order:** `rhcl-operator` syncWave `1`, `hub-gateway` / mesh syncWave `5`, `workshop-kuadrant-apis` syncWave `6`. If policies stay **Not Accepted**, verify `ISTIO_GATEWAY_CONTROLLER_NAMES` on the Kuadrant operator deployment and restart the pod (see [Connectivity Link](products/connectivity-link.md#rhcl--sailistio-mesh-required)).

```bash
bash scripts/apply-workshop-kuadrant-apis.sh
curl -sk -o /dev/null -w '%{http_code}\n' https://workshop-apis.<hub-domain>/httpbin/get
# Expect 401 without key
```

Catalog: System **workshop-kuadrant-apis** — Components + API entities for userN onboarding.

---

## MCP Gateway

Console link: `https://mcp-gateway.<hub-domain>/mcp` (expect **HTTP 200** on `/mcp`).

When Argo app `mcp-gateway` stays **Unknown** and the route returns **503**:

```bash
bash scripts/apply-mcp-gateway.sh
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
