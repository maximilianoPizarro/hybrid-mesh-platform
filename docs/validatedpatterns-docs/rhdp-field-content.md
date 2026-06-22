---
title: RHDP Field Content — 3 cluster orders (hub / east / west)
weight: 6
---

# RHDP Field Content — 3 cluster orders (hub / east / west)

Use **three separate catalog orders**, one per OpenShift cluster. Goal: a connected fleet where hub console links, ACM inventory, Skupper mesh, and Industrial Edge ingress all work — see [RHDP install playbook](install-improvements.md) for order, tokens, and validation.

## How RHDP injects cluster domain (`existing_gitops: true`)

RHDP does **not** template `values.yaml` in Git. It creates an Argo CD `Application` with inline `spec.source.helm.values` containing:

- `deployer.domain` ← `openshift_cluster_ingress_domain`
- `deployer.apiUrl` ← `openshift_api_url`
- `litemaas.apiKey` ← `litellm_virtual_key` (when `enable_litemaas_keys: true`)
- `litemaas.apiUrl` ← `litellm_api_base_url`
- `litemaas.model` ← catalog param `litemaas_model` (e.g. `deepseek-r1-distill-qwen-14b`)
- `litemaas.duration` ← `litemaas_duration` (e.g. `7d`, informational)

**Catalog → Helm mapping (your demo order):**

| Babylon / demo parameter | RHDP output (info template) | Helm `values` key |
|--------------------------|----------------------------|-------------------|
| `enable_litemaas_keys: true` | `litellm_virtual_key` | `litemaas.apiKey` |
| `litemaas_duration: 7d` | `litellm_key_duration` | `litemaas.duration` |
| `litemaas_model: deepseek-r1-distill-qwen-14b` | in `litellm_available_models_list` | `litemaas.model` |
| (implicit) | `litellm_api_base_url` | `litemaas.apiUrl` |

When `litemaas.model` is set, clustergroup `extraParametersNested` propagates it to `neuroface`, `kairos`, `devspaces.continueAi`, `developer-hub` Lightspeed, and ODS notebooks (via chart helpers). Chart defaults (`llama-scout-17b`, `granite-3-2-8b-instruct`) apply only when RHDP does not inject a model.

**Never put `{{ openshift_cluster_ingress_domain }}` in Git-tracked YAML** — Helm interprets `{{ }}` as Helm template syntax and Argo CD fails with `invalid map key`.

Hub templates use `deployer.domain` with fallback `apps.cluster.example.com`; RHDP overrides via Argo CD values.

## Catalog parameters

| Parameter | Hub | East | West |
|-----------|-----|------|------|
| `ocp4_workload_field_content_gitops_repo_url` | `https://github.com/maximilianoPizarro/hybrid-mesh-platform` | same | same |
| `ocp4_workload_field_content_gitops_repo_revision` | **`main`** | **`main`** | **`main`** |
| `ocp4_workload_field_content_gitops_repo_path` | **`charts/region/hub`** | **`charts/region/east`** | **`charts/region/west`** |
| `existing_gitops` | `true` | `true` | `true` |

Each path is a bootstrap Helm chart that renders `hybrid-mesh-platform-{hub,east,west}` and deploys VP **clustergroup** with `charts/region/<region>/values.yaml`. Shared components stay under `charts/all/`. See [Region strategy](region-strategy.md) and [REGIONS.md](../../REGIONS.md).

## Automatic cross-cluster domains (`fleet-values-sync`)

After RHDP provisions clusters and ACM shows **east** / **west** as **Available**, the **`fleet-values-sync`** CronJob (hub + spokes) removes most manual domain patching:

| Cluster | What it does |
|---------|----------------|
| **Hub** | Reads `ManagedCluster` API URLs + local ingress domain → patches `field-content` with `clusters.*`, `global.hubClusterDomain`, `managedClusters.*` → pushes `fleet-cross-cluster-config` ConfigMap to spokes via **ManifestWork** |
| **East / West** | Reads hub domain from ConfigMap → patches local `field-content` with `clusters.hub.domain` |

Schedule: every 30 minutes (`charts/all/fleet-values-sync`). Manual run from a logged-in cluster:

```bash
# Hub
oc create job --from=cronjob/fleet-values-sync fleet-values-sync-manual -n openshift-gitops

# Or offline script (requires PyYAML + oc token in pod / local kubeconfig)
python scripts/sync-fleet-values.py
```

**Spoke import tokens (`managedClusters`):** `fleet-values-sync` populates `managedClusters.*.apiUrl` from ACM `ManagedCluster` API URLs but does **not** inject tokens. To enable fully automated spoke auto-import via `acm-hub-spoke`, inject tokens at runtime — see [Spoke auto-import](install-improvements.md#spoke-auto-import-via-helm-values-acm-hub-spoke). Tokens are one-time; remove them from the Application patch after spokes are **Available**. MaaS keys remain RHDP-injected or secret-based.

## Recommended order

You can order **all three clusters in parallel** from the RHDP catalog; each path bootstraps independently. For the **fastest path to fleet value** (ACM ApplicationSet, hub-gateway, cross-cluster console links), prefer **hub first**, then east/west once MCH is **Running**.

| Order | Cluster | Path | Unlocks |
| ----- | ------- | ---- | ------- |
| 1 | **Hub** | `charts/region/hub` | ACM, Developer Hub, ACS Central, fleet observability, Skupper hub site |
| 2 | **East / West** | `charts/region/east`, `charts/region/west` | Industrial Edge, ACS Secured, spoke mesh, PULL GitOps |
| 3 | **Hub (day-two)** | `fleet-values-sync` job | Cross-cluster domains on spokes; Mailpit + ACS Central endpoints |

Allow **60–90 minutes** for full fleet sync. See [RHDP install playbook](install-improvements.md) for token handling, console links, and common RHDP pitfalls.

### Steps

1. **Hub** — revision `main`, path `charts/region/hub`; wait for `multiclusterhub` **Running**.
2. **East / West** — revision `main`, paths `charts/region/east` / `charts/region/west` (parallel OK).
3. **Import spokes in ACM** — prefer auto-import via `managedClusters.*.token` runtime patch (see [Spoke auto-import](install-improvements.md#spoke-auto-import-via-helm-values-acm-hub-spoke)) or ACM UI; avoid token churn in auto-syncing `field-content` (see playbook).
4. **Sync domains** — trigger `fleet-values-sync` once after clusters are **Available**:

```bash
oc create job --from=cronjob/fleet-values-sync fleet-values-sync-manual -n openshift-gitops
```

**Domains only** — `fleet-values-sync` does not manage spoke API tokens. Inject tokens via RHDP or manual ACM import, not repeated `field-content` patches during failed auto-import.

<details>
<summary>Legacy manual patch (domains + tokens — fallback only)</summary>

```bash
helm upgrade field-content . -f values.yaml \
  --set deployer.domain=apps.cluster-<hub>.dynamic2.redhatworkshops.io \
  --set deployer.apiUrl=https://api.cluster-<hub>.dynamic2.redhatworkshops.io:6443 \
  --set clusters.hub.domain=apps.cluster-<hub>.dynamic2.redhatworkshops.io \
  --set clusters.east.domain=apps.cluster-<east>.dynamic2.redhatworkshops.io \
  --set clusters.east.apiUrl=https://api.cluster-<east>.dynamic2.redhatworkshops.io:6443 \
  --set clusters.west.domain=apps.cluster-<west>.dynamic2.redhatworkshops.io \
  --set clusters.west.apiUrl=https://api.cluster-<west>.dynamic2.redhatworkshops.io:6443 \
  --set clusters.east.token=sha256~... \
  --set clusters.west.token=sha256~...
```

Or patch the Argo CD `Application` `field-content` `helm.values` with the same keys.

</details>

## Spoke orders — `clusters.hub.domain` (automated)

East and west RHDP orders inject `deployer.domain` for the **local** spoke. **`fleet-values-sync`** on each spoke patches `clusters.hub.domain` once the hub ManifestWork delivers `fleet-cross-cluster-config`.

| Feature | Uses `clusters.hub.domain` |
|---------|---------------------------|
| IE anomaly alerter → Mailpit | `https://mailpit.<hub-domain>/api/v1/send` |
| ACS SecuredCluster → Central | `central-stackrox.<hub-domain>:443` |
| Kairos hub reporting | `kairos-console-kairos-system.<hub-domain>` |
| Console links to hub services | Quay, Developer Hub, Mailpit |

Manual patch (fallback only):

```bash
# East spoke — after RHDP provision
oc patch application field-content -n openshift-gitops --type merge -p '
spec:
  source:
    helm:
      values: |
        deployer:
          domain: apps.cluster-<east-id>.dynamic2.redhatworkshops.io
        clusters:
          hub:
            domain: apps.cluster-<hub-id>.dynamic2.redhatworkshops.io
'
```

Repeat for west with `apps.cluster-<west-id>...` and the same `clusters.hub.domain`.

Without `clusters.hub.domain`, Mailpit URLs become `https://mailpit./api/v1/send` and ACS spokes cannot reach Central.

## Verify hub after provision

RHDP syncs **`charts/region/hub`** (or east/west path) as a bootstrap Helm chart, which creates Argo CD Application **`hybrid-mesh-platform-hub`**. That app deploys VP **clustergroup** with multisource valueFiles from this repo.

Legacy path `.` still works if you set `main.clusterGroupName` in RHDP helm values.

```bash
oc get application field-content -n openshift-gitops
oc get applications -n openshift-gitops -l validatedpatterns.io/pattern=hybrid-mesh-platform
```

Expect **`hybrid-mesh-platform-hub`** then child apps (`acm-hub-spoke`, `developer-hub`, `console-links`, …). Prove platform surfaces are reachable:

```bash
oc login --token=<token> --server=<hub-api-url>
MIN_OK_CODE=200 bash scripts/verify-console-links.sh   # hub — expect 19 OK
bash scripts/verify-fleet.sh
```

If sync is `Unknown`, check:

```bash
oc get application field-content -n openshift-gitops -o jsonpath='{.status.conditions[*].message}{"\n"}'
```

## MaaS API keys (hub — after sync)

With **`enable_litemaas_keys: true`**, RHDP injects `litemaas.*` into the `field-content` Application (see mapping table above). Chart **`vault-maas-external-secrets`** creates the facilitator seed automatically — no manual `oc create secret`:

1. **CronJob `maas-facilitator-rhdp-sync`** (every 5 min) reads `field-content` → Secret `maas-facilitator-seed` in `vault` → Vault `secret/workshop/maas` → ExternalSecrets.
2. When clustergroup passes `litemaas.apiKey`, Helm also renders the same Secret (sync-wave 3).
3. PostSync **`hub-post-install-vault-maas-eso`** triggers the CronJob once on day-2 bootstrap.

Verify:

```bash
oc get cronjob maas-facilitator-rhdp-sync -n vault
oc get secret maas-facilitator-seed -n vault
oc get application field-content -n openshift-gitops \
  -o jsonpath='{.spec.source.helm.valuesObject.litemaas.apiKey}{"\n"}'
```

Manual fallback (only if RHDP did not inject `litemaas.apiKey`):

```bash
oc create secret generic maas-facilitator-seed -n vault --from-literal=api-key='sk-...'
oc create job maas-facilitator-rhdp-sync-manual --from=cronjob/maas-facilitator-rhdp-sync -n vault
```

Day-2 mesh/workshop/ACS: Argo app **`hub-post-install-bootstrap`** (PostSync Jobs). ACS:

```bash
oc create secret generic acs-init-credentials -n stackrox --from-literal=ROX_ADMIN_PASSWORD='...'
oc annotate application hub-post-install-bootstrap -n openshift-gitops argocd.argoproj.io/refresh=hard --overwrite
```

| Model (RHDP MaaS alias) | Typical use |
|-------------------------|-------------|
| `llama-scout-17b` | Default userN / NeuroFace chat / Kairos |
| `granite-3-2-8b-instruct` | Developer Hub Lightspeed default |
| `deepseek-r1-distill-qwen-14b` | Optional ODS connection |

Use **separate** MaaS keys per model when your workshop provides them; never commit keys to Git.

## Local validation

```bash
helm template field-content charts/region/hub -f values-global.yaml \
  --set deployer.domain=apps.hub.example.com \
  --set deployer.apiUrl=https://api.hub.example.com:6443
```
