# Install Pattern Skill

## Prerequisites

- OpenShift **4.14+** (hub + two spokes recommended)
- Hub: 3+ workers, 8 vCPU, 32 GiB; Spoke: 3+ workers, 4 vCPU, 16 GiB
- `oc` cluster-admin, Helm 3, Git
- **RHDP:** three separate catalog orders (hub, east, west) — allow **60–90 min** for full fleet sync and console links to converge
- **Standalone:** fork repo, `./pattern.sh make install` on hub only; register spokes manually

## RHDP recommended order

**Option A — Hub first (fastest fleet value):**

1. Hub `charts/region/hub` → wait MCH **Running** (~10–15 min)
2. East / West in parallel
3. Import spokes in ACM (after MCH Running)
4. `fleet-values-sync` manual job (domains only)
5. `oc login` then `MIN_OK_CODE=200 bash scripts/verify-console-links.sh` — expect **19–20 OK** (IE link may 503 when disabled)

**Option B — Three orders in parallel:** valid; cross-cluster features converge when ACM import + domain sync complete.

Full playbook: `docs/validatedpatterns-docs/install-improvements.md`

## Quick Install (Standalone Hub)

```bash
git clone https://github.com/maximilianoPizarro/hybrid-mesh-platform.git
cd hybrid-mesh-platform
cp values-secret.yaml.template values-secret.yaml
# Edit secrets / MaaS keys if needed

oc login --token=<hub-token> --server=<hub-api-url>
./pattern.sh make install
```

Creates **`hybrid-mesh-platform-hub`** Application → VP clustergroup → child apps from `charts/region/hub/values.yaml`.

## RHDP Installation (3 cluster orders)

| Cluster | `ocp4_workload_field_content_gitops_repo_path` |
|---------|--------------------------------------------------|
| Hub | `charts/region/hub` |
| East | `charts/region/east` |
| West | `charts/region/west` |

RHDP injects via Argo `helm.values` (not Git):

- `deployer.domain` ← ingress domain
- `deployer.apiUrl`
- `litemaas.apiKey` / `litemaas.apiUrl` / `litemaas.model` (hub — never commit `sk-*` to Git)

**Never** use `{{ openshift_cluster_ingress_domain }}` in Git YAML.

Full parameter table: `docs/validatedpatterns-docs/rhdp-field-content.md`

### Hub field-content example

```yaml
spec:
  source:
    path: charts/region/hub
    repoURL: https://github.com/maximilianoPizarro/hybrid-mesh-platform
    targetRevision: main
    helm:
      values: |
        deployer:
          domain: apps.<hub-id>.dynamic2.redhatworkshops.io
          apiUrl: https://api.<hub-id>.dynamic2.redhatworkshops.io:6443
        global:
          localClusterDomain: apps.<hub-id>.dynamic2.redhatworkshops.io
          hubClusterDomain: apps.<hub-id>.dynamic2.redhatworkshops.io
```

### Spoke field-content

Same pattern with `charts/region/east` or `west`. Spokes get `deployer.domain` locally; **`clusters.hub.domain`** patched by `fleet-values-sync` after ACM import.

**Do not** put spoke API tokens in auto-syncing `field-content` helm.values — causes east/west namespace churn if import fails. Tokens = one-time ACM import or RHDP secret injection only.

### Spoke auto-import via `managedClusters` values

Setting `managedClusters.{east,west}.apiUrl` + `.token` in hub values triggers ACM auto-import. The `acm-hub-spoke` chart creates `ManagedCluster` + `KlusterletAddonConfig` + `auto-import-secret` when `apiUrl` is present.

**SA token creation on each spoke:**

```bash
oc create sa acm-auto-import -n kube-system
oc adm policy add-cluster-role-to-user cluster-admin -z acm-auto-import -n kube-system
oc create token acm-auto-import -n kube-system --duration=168h
```

**Runtime Application patch (no tokens in Git):**

Inject tokens via RHDP `field-content` Runtime Application `helm.values` or `oc patch`, never commit them to the repository. Example:

```bash
oc patch application field-content -n openshift-gitops --type merge -p '{
  "spec":{"source":{"helm":{"values":"managedClusters:\n  east:\n    apiUrl: https://api.<east>:6443\n    token: <token>\n  west:\n    apiUrl: https://api.<west>:6443\n    token: <token>"}}}}'
```

**Tokens are one-time:** ACM takes over cluster management after klusterlet joins. The token is only needed for initial import; once the managed cluster shows `JOINED`/`AVAILABLE` in `oc get managedclusters`, the token is no longer used and can expire.

## What gets deployed (hub)

Key clustergroup apps (see `charts/region/hub/values.yaml`):

| syncWave | App | Purpose |
|----------|-----|---------|
| 0 | openshift-gitops, developer-hub, neuroface-gateway, … | Platform base (**hub-gateway IE optional, disabled by default**) |
| 5 | fleet-values-sync | Cross-cluster domain sync |
| 6 | acm-hub-spoke | ApplicationSet `fleet-spoke-push` |
| 10 | console-links | OpenShift Console menu links |

## Verify Installation (product-focused)

```bash
oc login --token=<hub-token> --server=<hub-api-url>

# Bootstrap
oc get application field-content hybrid-mesh-platform-hub -n openshift-gitops
oc get multiclusterhub -n open-cluster-management -o jsonpath='{.items[0].status.phase}{"\n"}'  # expect Running

# Fleet
oc get managedclusters
oc get applicationset fleet-spoke-push -n openshift-gitops

# Primary smoke test — 19–20 hub console links (IE may 503 when disabled)
MIN_OK_CODE=200 bash scripts/verify-console-links.sh
bash scripts/verify-neuroface-cv.sh
bash scripts/verify-workshop-http200.sh
bash scripts/verify-fleet.sh

# Offline
bash scripts/argocd-preflight.sh
python scripts/verify-gitops-strategies.py
```

**Success:** `Summary: 19-20 OK (200-399), 0 503, 0 other` (or IE link counted as OK when disabled), exit code **0**. Requires `oc login` for OpenShift AI (OAuth).

**503 on first hour is normal** for Developer Hub, GitLab, ODS, Skupper — routes exist, backends still syncing. Strict gate: `MIN_OK_CODE=200 bash scripts/verify-console-links.sh`.

## Post-Install Tasks

1. Wait MCH **Running** before spoke import (`register-spoke` skill)
2. Register east/west — **`ManagedCluster` first** (ACM creates namespace); **one-time** tokens, not in auto-syncing GitOps values
3. Trigger domain sync: `oc create job --from=cronjob/fleet-values-sync fleet-values-sync-manual -n openshift-gitops`
4. Verify `east-spoke-components` / `west-spoke-components` on hub Argo CD
5. Console links — expect partial 503 until operators/CRs converge (60–90 min); target **19–20/20 HTTP 200** (IE optional)
6. AI CV gate: `bash scripts/verify-neuroface-cv.sh`; workshop gate: `bash scripts/verify-workshop-http200.sh` (skips IE when off), `verify-workshop-kuadrant-curl.sh`
7. Industrial Edge (optional): uncomment IE apps in `charts/region/east|west/values.yaml` + hub `hub-gateway`; then `VERIFY_IE=1 bash scripts/verify-industrial-edge.sh`
8. Skupper: hub `Site` + spoke `Site` + AccessToken sync job (`accesstoken-sync`); target `sitesInNetwork: 3`
9. MaaS secrets on hub if not via RHDP: `kairos-ai-credentials`, `openshift-ai-maas-credentials`
10. GitLab platform-content seed: CronJob `gitlab-platform-content-seed` in `gitlab` namespace (software templates — **`/-/blob/`** URLs in catalog)
11. Developer Hub rollout after catalog/plugin changes: allow 5–10 min for `install-dynamic-plugins` init
12. Spoke NeuroFace: PUSH app `spoke-neuroface` via `fleet-spoke-push`; OVMS ModelMesh InferenceService via wrapper templates in `charts/all/spoke-neuroface/templates/`

## Known install gotchas

- **ACM bootstrap stuck:** `helm template acm charts/all/acm-operator | oc apply -f -` if MCH CRD not ready after ~15 min
- **ACM spoke import:** Create **`ManagedCluster` before** any pre-labeled `Namespace` — see `charts/all/acm-hub-spoke/templates/managed-clusters.yaml`
- **ACM 2.16:** New installs get `resourceExclusions` from `openshift-gitops` chart + `cluster-proxy-addon: false` from `acm-operator`
- **OperatorGroups:** Do not set `operatorGroup: true` on `redhat-ods-operator` — RHODS needs AllNamespaces OG (`spec: {}`). Kubecost: **`kubecost-operator-group`**. Remove duplicate Kairos OG if present.
- **GitLab:** approve **Manual** InstallPlans in `gitlab` + `gitlab-runner`; Route `https://gitlab.apps.<domain>/`; seed `platform-content` for Developer Hub scaffolder templates
- **Developer Hub:** GitLab host must use `developer-hub.gitlabHost` helper (not `gitlab.apps.{{ clusterDomain }}`); catalog CMs need `extraFiles` mounts; software templates via `catalog-software-templates.yaml`; TechDocs use GitHub repo URL (not GitHub Pages) for readTree support
- **GitLab Runner:** disabled by default (`runnerEnabled: false`); namespace `gitlab-runner` must exist before enabling; stuck namespace → remove `finalizer.gitlab.com` from Runner CR
- **hub-post-install RBAC:** SA needs `bind`/`escalate` on `rbac.authorization.k8s.io` to create ClusterRoleBindings — already in chart; if deadlock, terminate operation + patch live + resync
- **VP Tests:** `make qe-tests` → `tests/interop/run_tests.sh`; requires `KUBECONFIG` + `INFRA_PROVIDER`; auto-resolves `HUB_APPS_DOMAIN` from cluster
- **Unsealvault:** suspend CronJob if Vault already initialized (`oc patch cronjob unsealvault-cronjob -n imperative --type merge -p '{"spec":{"suspend":true}}'`)
- **hub-gateway / Industrial Edge:** **disabled by default** — uncomment in region values to enable factory telemetry demo; validation uses `scripts/lib/ie-enabled.sh`
- **Workshop users:** IdP **`workshop-users`**; `grantClusterReader: true`; fix job `scripts/fix-htpasswd-users-secret-job.yaml`
- **CNV:** `cnv-example` includes Subscription + VM in **`cnv-workshop`**
- **Helm CI:** vendored `charts/*.tgz` for skupper/camel/neuroface; run `scripts/vendor-*-chart.sh`

## Documentation

- **RHDP playbook:** `docs/validatedpatterns-docs/install-improvements.md`
- Getting started: `docs/validatedpatterns-docs/getting-started.md`
- GitOps chain: `docs/validatedpatterns-docs/gitops-deployment-chain.md`
- Region strategy: `docs/validatedpatterns-docs/region-strategy.md`
