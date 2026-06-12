---
title: RHDP Field Content — 3 cluster orders (hub / east / west)
weight: 5
---

# RHDP Field Content — 3 cluster orders (hub / east / west)

Use **three separate catalog orders**, one per OpenShift cluster.

## How RHDP injects cluster domain (`existing_gitops: true`)

RHDP does **not** template `values.yaml` in Git. It creates an Argo CD `Application` with inline `spec.source.helm.values` containing:

- `deployer.domain` ← `openshift_cluster_ingress_domain`
- `deployer.apiUrl` ← `openshift_api_url`
- `litemaas.apiKey` / `litemaas.apiUrl` (MaaS — never commit `sk-*` keys to Git)
- `litemaas.model` — default `llama-scout-17b` (workshop); also `deepseek-r1-distill-qwen-14b`, `codellama-7b-instruct`

**Never put `{{ openshift_cluster_ingress_domain }}` in Git-tracked YAML** — Helm interprees `{{ }}` as Helm template syntax and Argo CD fails with `invalid map key`.

Hub templates use `deployer.domain` with fallback `apps.cluster.example.com`; RHDP overrides via Argo CD values.

## Catalog parameters

| Parameter | Hub | East | West |
|-----------|-----|------|------|
| `ocp4_workload_field_content_gitops_repo_url` | `https://github.com/maximilianoPizarro/hybrid-mesh-platform` | same | same |
| `ocp4_workload_field_content_gitops_repo_revision` | **`main`** | **`east`** | **`west`** |
| `ocp4_workload_field_content_gitops_repo_path` | `.` | `.` | `.` |
| `existing_gitops` | `true` | `true` | `true` |

Each branch sets `values-global.yaml` → `clusterGroupName` (`hub` / `east` / `west`) and spoke branches carry only their matching `values-*.yaml`. See [Branch strategy](branch-strategy.md).

## Recommended order

1. **Hub** — revision `main`, path `.`
2. **East** / **West** — revision `east` / `west`, path `.`
3. **Hub** — after ACM import, upgrade with spoke domains + tokens:

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

## Spoke orders — `clusters.hub.domain` (required)

East and west RHDP orders inject `deployer.domain` for the **local** spoke. Cross-cluster features also need the **hub** apps domain:

| Feature | Uses `clusters.hub.domain` |
|---------|---------------------------|
| IE anomaly alerter → Mailpit | `https://mailpit.<hub-domain>/api/v1/send` |
| ACS SecuredCluster → Central | `central-stackrox.<hub-domain>:443` |
| Kairos hub reporting | `kairos-console-kairos-system.<hub-domain>` |
| Console links to hub services | Quay, Developer Hub, Mailpit |

Patch **each spoke** `field-content` Application (or set in the second hub upgrade that also lists spoke tokens):

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

```bash
oc get application field-content -n openshift-gitops
oc get applications -n openshift-gitops -l app.kubernetes.io/part-of=platform-hub-spoke
```

Expect many `field-content-*` child apps after `field-content` syncs. If sync is `Unknown`, check:

```bash
oc get application field-content -n openshift-gitops -o jsonpath='{.status.conditions[*].message}{"\n"}'
```

## MaaS API keys (hub — after sync)

Inject via RHDP `litemaas.apiKey` in `field-content` helm.values, or create secrets manually:

```bash
# Kairos + Developer Hub Lightspeed
oc create secret generic kairos-ai-credentials -n kairos-system \
  --from-literal=api-key='sk-...' --dry-run=client -o yaml | oc apply -f -

# OpenShift AI playground / InferenceService proxies
oc create secret generic openshift-ai-maas-credentials -n maas-workshop \
  --from-literal=api-key='sk-...' \
  --from-literal=OPENAI_API_BASE='https://maas-rhdp.apps.maas.redhatworkshops.io/v1' \
  --dry-run=client -o yaml | oc apply -f -
```

Use separate MaaS keys per model if your workshop provides them; `llama-scout-17b` is the default for userN Lightspeed chat.

## Local validation

```bash
helm template test-hub . -f values.yaml \
  --set deployer.domain=apps.hub.example.com \
  --set deployer.apiUrl=https://api.hub.example.com:6443 \
  --set clusters.hub.domain=apps.hub.example.com
```
