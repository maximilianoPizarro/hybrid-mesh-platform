# Hybrid Mesh Platform - Overview Skill

## Pattern Overview

Hub-spoke multi-cluster GitOps on OpenShift (Validated Patterns, Sandbox tier). Fork of multicloud-gitops with **region paths** (`charts/region/{hub,east,west}`) and **50+ charts** under `charts/all/`.

**Problem it solves:** secure multi-cluster connectivity (Skupper VAN), centralized fleet GitOps (ACM + dual PUSH/PULL), **AI Computer Vision at the edge** (NeuroFace + OVMS ModelMesh on spokes, federated hub gateway), optional Industrial Edge factory telemetry, hub-resident AI/security/observability.

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
│   ├── verify-console-links.sh     # curl all ConsoleLink hrefs (IE link 503 OK when disabled)
│   ├── verify-workshop-http200.sh  # console links + workshop/AI strict 200 (skips IE when off)
│   ├── verify-neuroface-cv.sh      # NeuroFace CV gateway + PPE path (primary edge AI gate)
│   ├── verify-industrial-edge.sh   # Skupper VAN + IE route — skip unless VERIFY_IE=1 or hub-gateway
│   ├── lib/ie-enabled.sh           # IE optional detection (hub-gateway or VERIFY_IE=1)
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
| Developer experience | Developer Hub 200; catalog demos + Kuadrant APIs; software templates in `/create` after OIDC login (GitLab `/-/blob/` URLs) |
| **AI CV at edge** | `bash scripts/verify-neuroface-cv.sh` — `neuroface-cv.<hub>` health + PPE status 2xx; spoke `yolo-ppe-serving` Ready in `neuroface-cv` |
| NeuroFace app | `neuroface.<hub>` 200; hub `neuroface-gateway` 50/50 to east/west Skupper listeners |
| Industrial Edge *(optional)* | `VERIFY_IE=1 bash scripts/verify-industrial-edge.sh` — hub IE route 200, Skupper VAN=3; **skipped by default** when `hub-gateway` not deployed |
| Private mesh | Skupper `sitesInNetwork: 3` on hub site |

Smoke test (hub — default install, IE disabled):

```bash
oc login --token=<token> --server=<hub-api-url>
MIN_OK_CODE=200 bash scripts/verify-console-links.sh   # expect 19–20 OK (IE may 503), exit 0
bash scripts/verify-workshop-http200.sh                # skips industrial-edge + line-dashboard when IE off
bash scripts/verify-neuroface-cv.sh                    # primary AI CV gate
bash scripts/verify-workshop-kuadrant-curl.sh            # 401 without API key = OK
bash scripts/verify-fleet.sh
# IE only when enabled:
VERIFY_IE=1 bash scripts/verify-industrial-edge.sh
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
| **Hub** | `charts/region/hub` | ACM, Developer Hub, ACS Central, Skupper listeners, Grafana, Kafka Console, **`neuroface-gateway`** (50/50 CV), RHCL |
| **East/West** | `charts/region/east\|west` | **`spoke-neuroface`** (full app + OVMS ModelMesh), **`spoke-neuroface-cv`** (PPE KServe), ACS Secured, Skupper connectors, ambient mesh |
| **Optional** | region values (commented) | `hub-gateway`, `industrial-edge-*`, `spoke-gateway` — enable explicitly for factory telemetry demo |

## GitOps Strategy

| Strategy | Mechanism | Charts (examples) |
|----------|-----------|-------------------|
| **PUSH** | Hub ApplicationSet `fleet-spoke-push` | `operators-ci`, `operators-platform`, **`spoke-neuroface`** via `spoke-meta-push` |
| **PULL** | Spoke clustergroup / managedClusterGroups | **`spoke-neuroface-cv`**, mesh, observability, `operators-edge`; IE stack only when uncommented in region values |

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
| Industrial Edge (hub GW) | `industrial-edge.<hubDomain>` | **Optional** — `charts/all/hub-gateway` disabled by default; link may 503 until enabled |
| GitLab | `gitlab.apps.<domain>` | GitLab Operator standard profile; approve Manual InstallPlans |
| OpenShift AI | `rh-ai.apps.<domain>` | AllNamespaces OG; legacy `rhods-dashboard-*` redirects to rh-ai |
| Kubecost | `kubecost.<domain>` | OG **`kubecost-operator-group`** |
| Vault | `vault.<domain>/ui/` | Root route returns 307 |
| Workshop login | OAuth IdP **`workshop-users`** | `platform-users` chart; `grantClusterReader: true` for console middleware menu |

Verify:

```bash
oc login --token=<token> --server=<hub-api-url>
MIN_OK_CODE=200 bash scripts/verify-console-links.sh
bash scripts/verify-neuroface-cv.sh          # AI CV primary gate
bash scripts/verify-workshop-http200.sh
# VERIFY_IE=1 bash scripts/verify-industrial-edge.sh   # only when IE enabled
```

## Key Files

| File | Purpose |
|------|---------|
| `charts/region/hub/values.yaml` | Hub apps, sync waves, neuroface-gateway/skupper overrides |
| `charts/all/spoke-neuroface/` | Full NeuroFace stack on spokes (OVMS ModelMesh face detection, Kafka, Grafana) |
| `charts/all/spoke-neuroface/templates/modelmesh-*.yaml` | Wrapper InferenceService + model download (subchart hooks don't run on Argo upgrade) |
| `charts/all/neuroface-gateway/` | Hub Gateway API 50/50 to east/west CV listeners |
| `charts/all/acm-hub-spoke/` | Placement, ApplicationSet `fleet-spoke-push`, GitOpsCluster |
| `charts/all/openshift-gitops/templates/argocd.yaml` | ArgoCD CR + ACM 2.16 resourceExclusions |
| `charts/all/acm-operator/` | ACM subscription + MCE `cluster-proxy-addon: false` automation |
| `charts/all/gitlab-operator/` | GitLab Operator + Runner + platform-content seed (CronJob/Job) |
| `charts/all/developer-hub/` | RHDH Backstage, catalog CMs, Kuadrant plugin, GitLab/Tekton dynamic plugins |
| `charts/all/skupper-network-observer/` | OCI network-observer wrapper + passthrough Route |
| `charts/all/openshift-ai-hub/` | DSCInitialization v2, DataScienceCluster v2 RawDeployment |
| `charts/all/console-links/templates/all.yaml` | ConsoleLink hrefs |
| `charts/all/rhcl-operator/` | RHCL subscription + `ISTIO_GATEWAY_CONTROLLER_NAMES` for Sail/Istio |
| `charts/all/workshop-kuadrant-apis/` | Workshop Gateway API + Kuadrant APIProducts, AuthPolicy, PlanPolicy |
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
| Docs index | `docs/validatedpatterns-docs/DOC-INDEX.md` |

## Common Operations

```bash
# Fleet
oc get managedclusters
oc get applicationset fleet-spoke-push -n openshift-gitops

# Day-2: PostSync Jobs (Argo app hub-post-install-bootstrap, sync wave 9)
oc get jobs -n openshift-gitops | grep hub-post-install
oc annotate application hub-post-install-bootstrap -n openshift-gitops argocd.argoproj.io/refresh=hard --overwrite

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
- **Every catalog ConfigMap** referenced in `app-config` must have a matching `extraFiles` mount in `charts/all/developer-hub/templates/backstage-developer-hub.yaml` (e.g. `cnv-workshop`, `software-templates`)
- **GitLab host helper:** use `developer-hub.gitlabHost` in templates — **never** `gitlab.apps.{{ clusterDomain }}` because `clusterDomain` is already `apps.<cluster>` → double `apps` (`gitlab.apps.apps.*`) breaks integrations, proxy, scaffolder, pipelines UI
- **Software templates:** Backstage cannot read GitLab `/-/raw/` URLs. Bundle Location in `catalog-software-templates.yaml` with explicit `/-/blob/main/...` targets; mount at `/opt/app-root/src/catalog-data/software-templates/`
- **OpenAPI catalog entities:** `spec.definition` must be a **string** — use `definition: |` for inline YAML; `$text: <url>` only for external URLs; nested YAML objects fail validation
- **RBAC:** `plugins.rbac.enabled: true` — unauthenticated `/api/catalog/entities?filter=kind=template` returns `[]`; templates visible only after OIDC login
- **Rollout triggers:** changes to `Backstage` CR `extraFiles`, `dynamic-plugins-rhdh`, or init-heavy config → expect 5–10 min `install-dynamic-plugins` init before pod Ready
- **Argo drift (non-blocking):** `Secret/developer-hub-oidc-auth`, `Secret/llama-stack-secrets`, `ServiceAccount/pipeline` often stay OutOfSync (runtime-managed)

### Developer Hub GitLab + scaffolder

| Piece | Path / note |
|-------|-------------|
| App config | `charts/all/developer-hub/templates/configmap-app-config-rhdh.yaml` |
| GitLab host helper | `charts/all/developer-hub/templates/_helpers.tpl` → `developer-hub.gitlabHost`, `platformContentBaseUrl` |
| Dynamic plugins (Tekton, GitLab pipelines OCI) | `configmap-dynamic-plugins-rhdh.yaml` |
| Platform content seed | `charts/all/gitlab-operator/templates/*-gitlab-platform-content-seed.yaml` → GitLab project `developer-hub/platform-content` |
| Software templates source | `docs/assets/backstage/software-templates/` (seeded to GitLab; catalog index bundled in-chart) |
| Kuadrant APIs catalog | `files/catalog/workshop-kuadrant-apis.yaml` → CM `developer-hub-catalog-workshop-kuadrant-apis` |

### Grafana Kafka metrics (hub dashboards, spoke data)

Hub Grafana queries `prometheus-east` / `prometheus-west` via `prometheus-auth-proxy` on spokes. **No data** causes:

1. **`prometheus-auth-proxy` CrashLoop** on restricted SCC — nginx needs OpenShift-compatible cache paths (`charts/all/spoke-interconnect/templates/deployment-prometheus-auth-proxy.yaml`)
2. **Missing `strimzi-kafka-metrics` PodMonitors** on spokes — sync `istio-monitoring` on east/west; hub values need `clusterSuffix: "-east"` / `"-west"` in `charts/region/east|west/values.yaml`

Verify from hub: query `kafka_server_kafkaserver_brokerstate` via `prometheus-east` datasource in Grafana or Thanos.

### NeuroFace PPE serving (v1.4.1 — KServe InferenceService)

- **Pre-built image:** `quay.io/maximilianopizarro/neuroface-ppe-serving:v1.4.1` — torch+ultralytics+opencv-headless baked in; cold start ~60s (model load from MinIO, no pip install)
- **KServe v1+v2:** `/v1/predict` (raw JPEG, backward compat) + `/v2/models/yolo-ppe/infer` + `/v2/models/yolo-ppe/ready`
- **ServingRuntime + InferenceService:** RawDeployment mode; model from `aws-connection-ppe-models` DataConnection → `s3://models/ppe-detection/model/best.pt`
- **MinIO model seed:** PostSync Job `minio-ppe-model-seed` in `industrial-edge-minio` downloads `best.pt` from HuggingFace → MinIO
- **Hub endpoint:** `neuroface.ppe.endpoint: http://yolo-ppe-serving:8080` (hub-local InferenceService); federated CV gateway at `neuroface-cv.<hub>` is separate (50/50 east/west via Skupper)
- **opencv-python-headless:** UBI9 base lacks `libGL.so.1`; image must use `opencv-python-headless` (not `opencv-python`). Dockerfile: `pip uninstall -y opencv-python && pip install --force-reinstall --no-deps opencv-python-headless` — the `--force-reinstall --no-deps` is required because `pip install` alone skips reinstall when metadata matches but shared `cv2/` module files were deleted by the uninstall
- **imagePullPolicy:** `Always` on ServingRuntime to avoid stale cached image layers during iterative fixes
- **PPE bypass routes:** Never create OpenShift Routes pointing `/api/ppe/*` directly to YOLO — YOLO expects raw JPEG binary, the backend does base64→JPEG conversion. Only Route `neuroface` → frontend is needed
- **Data persistence:** `ppe.dataPersistence.enabled: true` — backend uploads detection frames + annotations to `s3://models/ppe-detection/training-data/` for retraining in `ppe-retrain-workbench`
- **Ambient mesh:** `neuroface` (hub) and `neuroface-cv` (spokes) labeled `istio.io/dataplane-mode: ambient`; predictor pods labeled `istio.io/dataplane-mode: none` (CPU inference bypasses ztunnel)
- **Argo CD caching:** ServingRuntime `spec.containers` can get cached after merge-patch; if Argo applies old spec, delete ServingRuntime + InferenceService then let Argo recreate: `oc delete servingruntime yolo-ppe-runtime -n neuroface && oc delete inferenceservice yolo-ppe-serving -n neuroface`
- **ConfigMap endpoint drift:** Argo may revert `neuroface-config` ConfigMap `NEUROFACE_PPE_ENDPOINT` to subchart default; after fix in values.yaml, patch live + restart backend: `oc patch configmap neuroface-config -n neuroface --type merge -p '{"data":{"NEUROFACE_PPE_ENDPOINT":"http://yolo-ppe-serving:8080"}}' && oc rollout restart deploy/neuroface-backend -n neuroface`
- **PVC Multi-Attach:** `neuroface-data` is RWO; rolling update blocks if old pod holds PVC — force-delete old pod: `oc delete pod <old> -n neuroface --force --grace-period=0`

### Industrial Edge GitOps (optional — east/west spokes)

**Default:** IE apps commented out in `charts/region/east|west/values.yaml`; `hub-gateway` commented in hub values. Validation scripts skip IE unless `VERIFY_IE=1` or `hub-gateway` Gateway exists.

When enabled:
- Full IE stack deploys on **east/west** via `industrial-edge-tst` Argo app on spoke GitOps
- **PostSync hook trap:** `camel-k-registry-bootstrap` as PostSync hook can stall sync indefinitely — use sync-wave Job instead; TTL extended to 24h to survive Argo resync
- **AMQ broker security:** sensors connect without MQTT credentials — `ActiveMQArtemisSecurity` CR with `guestLoginModule` + `brokerProperties: securityEnabled=false` in `messaging.yaml`
- **Kafka advertised DNS:** Strimzi `advertisedHost` includes clusterName (`-east/-west`); ExternalName Service `dev-cluster-broker-0-<clusterName>` CNAMEs to real headless pod
- **Camel K registry auth:** `camel-k-registry-docker` secret expires when SA token rotates; bootstrap Job recreates it; TTL 24h keeps Job visible in Argo
- **Hub gateway architecture:** single URL `industrial-edge.<hub>` serves both frontend (port 8080) and WebSocket API (port 3000) via separate Skupper listeners/connectors:
  - `ie-gateway-east/west:8080` → `line-dashboard:8080` (Angular frontend)
  - `ie-api-east/west:3000` → `line-dashboard:3000` (iot-consumer socket.io)
  - HTTPRoute: `/api/service-web/socket` → ie-api (port 3000), `/*` → ie-gateway (port 8080)
- **config.json `websocketHost`:** must be `https://industrial-edge.<hub-domain>` (not empty string — socket.io v2 resolves `""` to `localhost:3000`); injected via `global.hubClusterDomain` override in region values
- **Spoke-gateway bypass:** `ie-gateway` Skupper connector points directly to `line-dashboard:8080` (not `spoke-gateway-istio`) because spoke Istio GatewayClass may not be programmed on RHDP spokes

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

### Kuadrant policies Not Accepted (RHCL + Sail mesh)

**Symptom:** AuthPolicy / PlanPolicy show **Invalid (Not Accepted)** — `MissingDependency: Gateway API provider (istio / envoy gateway) is not installed`.

**Cause:** RHCL CSV sets `ISTIO_GATEWAY_CONTROLLER_NAMES=openshift.io/gateway-controller/v1` but Sail/Istio `GatewayClass istio` uses `istio.io/gateway-controller`. Kuadrant also detects the provider only at **pod startup** (often before mesh is ready).

**Fix (Git):** `charts/all/rhcl-operator` subscription `spec.config.env` + `workshop-kuadrant-apis` PostSync restart job. Hub syncWave: `workshop-kuadrant-apis` at **`6`** (after `hub-gateway`).

**Day-2:**

```bash
oc annotate application hub-post-install-bootstrap -n openshift-gitops argocd.argoproj.io/refresh=hard --overwrite
oc get authpolicy,planpolicy -A -o custom-columns='NAME:.metadata.name,ACCEPTED:.status.conditions[?(@.type=="Accepted")].status,ENFORCED:.status.conditions[?(@.type=="Enforced")].status'
oc get kuadrant kuadrant -n kuadrant-system -o jsonpath='Ready={.status.conditions[?(@.type=="Ready")].status}{"\n"}'
```

**Developer Hub API keys:** `/kuadrant` — ClusterRole `developer-hub-kuadrant`; AuthPolicy secret selector `app` must match APIProduct name (`workshop-mcp-gateway`, `workshop-llm-tokens`, …).

**Kuadrant APIProducts plans sync:** PostSync Job `workshop-kuadrant-sync-plans` — Python 3.6 on UBI needs `universal_newlines=True` (not `text=True`) in `subprocess` calls (`charts/all/workshop-kuadrant-apis/templates/job-sync-apiproduct-plans.yaml`).

**Kuadrant sync-plans Job immutable:** the `workshop-surfaces.sh` script runs `helm template | oc apply` on the kuadrant chart. Jobs are immutable — delete existing job before apply: `oc delete job workshop-kuadrant-sync-plans -n workshop-kuadrant-apis --ignore-not-found` (included in `charts/all/hub-post-install-bootstrap/templates/configmap-scripts.yaml`).

### GitLab Runner (`runnerEnabled`)

The `gitlab-runner-operator` and `Runner` CR are guarded by `runnerEnabled: true/false` in `charts/all/gitlab-operator/values.yaml`. Set `runnerEnabled: false` when the `gitlab-runner` namespace is removed or the runner operator is not installed. Resources guarded: OperatorGroup, Subscription, Runner CR, Role, RoleBinding, bootstrap job runner token setup.

**Bootstrap job runner token:** checks `oc get ns ${RUNNER_NS}` before trying to create `gitlab-runner-token` secret — fails gracefully when namespace is absent.

### GitLab Dedicated Gateway

Chart `charts/all/gitlab-operator/templates/gitlab-gateway.yaml`:
- `Gateway/gitlab-gateway` in `gitlab` namespace — Istio mesh visibility, circuit breaking
- `HTTPRoute/gitlab-http` — routes LFS/upload (120s timeout), KAS WebSocket (`/-/kubernetes`), default HTTP
- `Route/gitlab-gateway-route` → `gitlab-gw.apps.<domain>` (edge TLS)
- Separate from the operator-managed `gitlab-apps` Route

**GitLab workshop scaling** (`charts/all/gitlab-operator/values.yaml`):
- webservice: maxReplicas **8**, CPU request 1/limit 3, memory limit 5Gi
- sidekiq: maxReplicas **6**
- gitlabShell: maxReplicas **5**

### Kairos SmartScalingPolicies for GitLab

File: `charts/all/kairos/templates/gitlab-scaling-policies.yaml`
- Policies: `gitlab-webservice-workshop`, `gitlab-sidekiq-workshop`, `gitlab-kas-workshop`, `gitlab-registry-workshop`
- Label: `kairos.io/policy-type: workshop-platform`
- Makes GitLab resources visible in Kairos Console UI
- Note: Kairos agent "Watching 0 resources" = no policy-triggered events yet (all healthy) — this is correct behavior

### hub-post-install-bootstrap RBAC escalation

The SA `system:serviceaccount:openshift-gitops:hub-post-install-bootstrap` needs `bind` and `escalate` verbs on `rbac.authorization.k8s.io` to create ClusterRoleBindings granting the `edit` ClusterRole to the showroom SA.

**Fix:** `charts/all/hub-post-install-bootstrap/templates/rbac.yaml` includes:
```yaml
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["clusterroles","clusterrolebindings","roles","rolebindings"]
  verbs: ["get","list","watch","create","update","patch","delete","bind","escalate"]
```

**Deadlock pattern:** if Argo is stuck in a PostSync hook waiting for a resource that needs the RBAC rule to be applied, break the deadlock:
```bash
oc patch application hub-post-install-bootstrap -n openshift-gitops --type merge -p '{"operation":null}'
oc patch clusterrole hub-post-install-bootstrap --type json -p '[{"op":"add","path":"/rules/-","value":{...}}]'
# then re-sync
```

### Developer Hub TechDocs — integrations.github vs gitlab

**Bug:** adding GitLab host under `integrations.github` causes Backstage to call GitLab with GitHub API paths (`/repos/` → 404 instead of `/projects/`). Fix: GitLab host ONLY under `integrations.gitlab`, never under `integrations.github`.

**TechDocs readTree:** `FetchUrlReader` (used for generic `url:` and GitHub Pages URLs) does NOT implement `readTree`. Use:
- `url:https://github.com/<owner>/<repo>/tree/main/<path>` → `GithubUrlReader` supports readTree via GitHub API
- `url:https://gitlab.../.../-/tree/main/<path>` → `GitlabUrlReader` supports readTree (only works if host NOT in `integrations.github`)
- `dir:./techdocs` → local (works only for entities with proper filesystem source)

### VP Interop Tests

Location: `tests/interop/` — run with `make qe-tests` or `cd tests/interop && ./run_tests.sh`.

Required env: `KUBECONFIG` (hub), `KUBECONFIG_EDGE` (east), `INFRA_PROVIDER`, optional `HUB_APPS_DOMAIN`.

Test files:
- `test_subscription_status_hub.py` — 13 hub operators (ACM, GitLab, RHCL, Kairos, ESO…)
- `test_subscription_status_edge.py` — 4 spoke operators
- `test_validate_hub_site_components.py` — pods, ArgoCD apps, ACM spokes
- `test_validate_edge_site_components.py` — neuroface/neuroface-cv ns; IE ns only if `VERIFY_IE=1`
- `test_workshop_surfaces.py` — HTTP checks + Kuadrant 401; IE surfaces skipped unless `VERIFY_IE=1`
- `test_platform_components.py` — Skupper VAN sites, GitLab Gateway, Kairos policies, Kuadrant
- `test_modify_web_content.py` — E2E GitOps roundtrip via showroom title

GitHub Actions: `.github/workflows/interop-tests.yml` (manual trigger via `workflow_dispatch`).

### Unsealvault CronJob

The `unsealvault-cronjob` in the `imperative` namespace runs every 5 min and tries to create the `secret` KV backend in Vault. **If Vault is already initialized and unsealed** (Sealed=false), suspend the CronJob to stop flooding:

```bash
oc patch cronjob unsealvault-cronjob -n imperative --type merge -p '{"spec":{"suspend":true}}'
oc delete pods -n imperative --field-selector=status.phase=Failed
```

### NeuroFace CV Journey (primary demo — hub-and-spoke)

- **Spoke full stack:** `charts/all/spoke-neuroface/` — NeuroFace app, Kafka, Grafana, **OVMS ModelMesh** face detection (`externalUrl: modelmesh-serving.redhat-ods-applications.svc:8008`)
- **Spoke PPE inference:** `charts/all/spoke-neuroface-cv/` — KServe `yolo-ppe-serving` in `neuroface-cv` namespace; model from MinIO via Skupper
- **Gateway:** `charts/all/neuroface-gateway/` — Gateway API `HTTPRoute` with 50/50 weights to Skupper listeners `neuroface-cv-east` / `neuroface-cv-west`
- **Skupper connector:** `neuroface-cv-<clusterName>` routing key; spoke publishes `yolo-ppe-serving.neuroface-cv.svc:8080`
- **Grafana dashboard:** `neuroface-cv` — gateway req/s, east vs west split, inference latency
- **Monitoring:** `istio-monitoring` PodMonitors extended for `neuroface` (hub) and `neuroface-cv` (spokes via `clusterSuffix`)
- **Public Route:** `https://neuroface-cv.<hub-domain>` — inference-only (`/health`, `/v1/predict`, `/v2/models/yolo-ppe/infer`)
- **Host header:** The gateway HTTPRoute matches by hostname; internal calls without `Host: neuroface-cv.<hub>` return 404. Backend PPE should use hub-local `yolo-ppe-serving:8080`, not the gateway

### NeuroFace upstream repo (github.com/maximilianoPizarro/neuroface)

- **Helm chart:** `helm/neuroface/` — published at `https://maximilianopizarro.github.io/neuroface/`
- **PPE serving image:** `ppe-serving/Dockerfile` + `ppe-serving/requirements.txt` + `ppe-serving/server.py`
- **GitHub Actions:** `.github/workflows/build-push-quay.yml` — builds backend, frontend, ppe-serving; publishes Helm chart
- **Version bumps:** Update `helm/neuroface/Chart.yaml` version + `values.yaml` image tags + workflow `IMAGE_TAG` default; push triggers build + Helm chart publish
- **Showroom:** Module 27 in `showroom-hybrid-mesh-ai` — architecture diagrams from `docs/screenshots/rh_*.png`

## External links

- GitHub Pages: https://maximilianopizarro.github.io/hybrid-mesh-platform/
- NeuroFace: https://github.com/maximilianoPizarro/neuroface
- Showroom: https://github.com/maximilianoPizarro/showroom-hybrid-mesh-ai
- Bill of Materials: `docs/bill-of-materials.md`
