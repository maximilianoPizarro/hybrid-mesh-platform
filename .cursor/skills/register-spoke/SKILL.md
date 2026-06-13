# Register Spoke Skill

## Overview

Register east/west spoke clusters in ACM on the hub cluster.

## Prerequisites

- Hub cluster with ACM installed and **MCH phase Running**
- Spoke cluster API URL and token
- `oc` CLI logged into hub cluster

**Critical:**

1. Do **not** put spoke tokens in auto-syncing `field-content` / `acm-hub-spoke` values while import is failing — ACM will terminate/recreate east/west namespaces in a loop.
2. Do **not** pre-create a `Namespace` with label `cluster.open-cluster-management.io/managedCluster` before the `ManagedCluster` CR — OpenShift enters a **Terminating** loop. **Create `ManagedCluster` first**; ACM creates the cluster namespace.
3. Import once via UI or chart/manual steps below, then sync domains only.

## Manual Registration

### 1. Create ManagedCluster (first — ACM creates namespace)

```bash
# On hub cluster — do NOT oc create namespace east/west with managedCluster label first
cat <<EOF | oc apply -f -
apiVersion: cluster.open-cluster-management.io/v1
kind: ManagedCluster
metadata:
  name: east  # or west
  labels:
    cluster.open-cluster-management.io/clusterset: global
    hybrid-mesh.io/region: east  # or west
    vendor: OpenShift
spec:
  hubAcceptsClient: true
  leaseDurationSeconds: 60
EOF
```

Wait until namespace `east` (or `west`) exists — created by ACM.

### 2. Create Auto-Import Secret

```bash
# Get spoke cluster token
SPOKE_TOKEN="sha256~..."
SPOKE_API="https://api.spoke-cluster.example.com:6443"

cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: auto-import-secret
  namespace: east  # or west
stringData:
  autoImportRetry: "5"
  token: "${SPOKE_TOKEN}"
  server: "${SPOKE_API}"
type: Opaque
EOF
```

### 3. Create KlusterletAddonConfig

```bash
cat <<EOF | oc apply -f -
apiVersion: agent.open-cluster-management.io/v1
kind: KlusterletAddonConfig
metadata:
  name: east  # or west
  namespace: east  # or west
spec:
  clusterName: east  # or west
  clusterNamespace: east  # or west
  applicationManager:
    enabled: true
  certPolicyController:
    enabled: true
  iamPolicyController:
    enabled: true
  policyController:
    enabled: true
  searchCollector:
    enabled: true
EOF
```

### 4. Create GitOpsCluster (if not already from chart)

```bash
cat <<EOF | oc apply -f -
apiVersion: apps.open-cluster-management.io/v1beta1
kind: GitOpsCluster
metadata:
  name: hub-spoke-gitops
  namespace: openshift-gitops
spec:
  argoServer:
    cluster: local-cluster
    argoNamespace: openshift-gitops
  placementRef:
    kind: Placement
    apiVersion: cluster.open-cluster-management.io/v1beta1
    name: hub-spoke-placement
    namespace: openshift-gitops
EOF
```

## Automated Registration

The `acm-hub-spoke` chart registers spokes when values include tokens — **one-time import only**:

```yaml
# overrides/values-aws-hub.yaml — ONE-TIME import only; never commit tokens to Git
managedClusters:
  east:
    apiUrl: https://api.east-cluster.example.com:6443
    domain: apps.east-cluster.example.com
    token: "sha256~..."   # prefer RHDP secret or ACM UI instead
  west:
    apiUrl: https://api.west-cluster.example.com:6443
    domain: apps.west-cluster.example.com
    token: "sha256~..."
```

**Chart order (Git):** `ManagedCluster` → `auto-import-secret` → `KlusterletAddonConfig` — no pre-labeled Namespace. See `charts/all/acm-hub-spoke/templates/managed-clusters.yaml`.

**During failed import:** Disable auto-sync or `Prune=false` on `acm-hub-spoke` so empty `managedClusters` in Git does not prune live resources.

**Anti-pattern:** Tokens in `field-content` helm.values while Argo auto-syncs `acm-hub-spoke` → namespace churn on failed import.

**Preferred:** ACM UI import or manual steps above, then remove token fields from GitOps values.

## Verify Registration

```bash
oc get managedclusters
oc get secrets -n openshift-gitops -l argocd.argoproj.io/secret-type=cluster
oc get gitopscluster -A
oc get applicationset fleet-spoke-push -n openshift-gitops
oc get applications -n openshift-gitops | grep spoke-components
```

Expected: `east`, `west`, `local-cluster` Available; ApplicationSet generates `east-spoke-components` and `west-spoke-components`.

## Post-registration

1. **`fleet-values-sync`** patches **domains only** (`clusters.hub.domain`, spoke domains on hub) — not tokens:

```bash
oc create job --from=cronjob/fleet-values-sync fleet-values-sync-manual -n openshift-gitops
```

2. On each spoke, `fleet-values-sync` patches `clusters.hub.domain` once hub delivers `fleet-cross-cluster-config` ManifestWork.
3. Spoke **`hybrid-mesh-platform-east|west`** syncs PULL apps from `charts/region/east|west/values.yaml`.
4. Hub PUSH apps deploy via `charts/all/spoke-meta-push` from ApplicationSet.

Without `clusters.hub.domain`, spoke Mailpit URLs break (`https://mailpit./api/v1/send`) and ACS cannot reach Central.

Manual domain fallback: patch `field-content` helm.values on spoke — see `docs/validatedpatterns-docs/rhdp-field-content.md` (tokens in `<details>` fallback only).

Playbook: `docs/validatedpatterns-docs/install-improvements.md#spoke-tokens-and-field-content`

## Troubleshooting join

```bash
# Hub — namespace churn
oc get managedcluster east -o yaml | grep -A5 conditions
oc get ns east -o jsonpath='{.status.phase}{"\n"}'
# Terminating loop → (a) remove tokens from GitOps values OR (b) pre-created Namespace with managedCluster label before ManagedCluster
oc get manifestworks -A | grep east

# Spoke
oc get pods -n open-cluster-management-agent
oc get klusterlet
```
