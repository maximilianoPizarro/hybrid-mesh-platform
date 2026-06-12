---
title: Deploy with ACM and GitOps
weight: 6
---

# Deploy with ACM and GitOps

This guide explains how Red Hat ACM primitives cooperate with OpenShift GitOps (Argo CD) to drive hub-spoke deployment from Git.

## ManagedClusterSet

A **ManagedClusterSet** groups clusters for RBAC and placement. Typical patterns:

- One set for all fleet clusters.
- Separate sets for production vs non-production.

Cluster membership in a set is what downstream objects reference—not individual cluster names embedded in static YAML.

## Placement

**Placement** selects clusters from a `ManagedClusterSet` using label selectors or predicates. ACM computes intent continuously as clusters join, leave, or change labels.

Example concerns:

- Select `region=east` for east-only workloads.
- Require feature labels such as `environment=prod`.

## PlacementDecision

ACM publishes **PlacementDecision** objects listing concrete cluster names that satisfied a `Placement` at a given time. GitOps integrations watch these decisions to know *where* to apply manifests without hardcoding kube-apiserver URLs in Git.

## GitOpsCluster

A **GitOpsCluster** resource associates Argo CD (`spec.argocd`) with clusters chosen by placement. It bridges ACM’s fleet selection with Argo CD’s cluster secrets and Application destinations.

Together, `Placement` → `PlacementDecision` → `GitOpsCluster` avoids brittle per-cluster Application YAML checked into Git.

## ApplicationSet with clusterDecisionResource

The **ApplicationSet** uses a **`clusterDecisionResource`** generator that reads ACM **PlacementDecision** objects. For each cluster selected by the Placement, the ApplicationSet creates an Application that deploys the cluster's dedicated Helm chart folder to the remote spoke.

The ApplicationSet template uses two dynamic variables from the PlacementDecision:
- **`{{name}}`** — cluster name (e.g. `east`, `west`), used as both the repository `path` and the `destination.name`
- **`{{server}}`** — cluster API server URL (available but not used directly; `destination.name` resolves via cluster secrets)

This means adding a new spoke with correct labels and a matching folder in the repository automatically generates a new Application.

## Remote deployment model

Each cluster has its own Argo CD instance. The hub's ApplicationSet pushes the per-cluster chart to each spoke's `openshift-gitops` namespace. The spoke's Argo CD then manages the child Applications locally.

```
Hub ArgoCD → ApplicationSet
  → east-spoke-components (source: east/, destination: east cluster)
       → east/templates/ generates child Application CRs
            → East ArgoCD syncs child apps locally
  → west-spoke-components (source: west/, destination: west cluster)
       → west/templates/ generates child Application CRs
            → West ArgoCD syncs child apps locally
```

Industrial Edge components exist ONLY in spoke charts. The hub chart never includes them.

## Troubleshooting: `fleet-spoke-push` shows no Applications

The OpenShift / ACM UI may report *no Argo applications* when any link in this chain is missing:

1. **Managed clusters** are **Imported / Available** (`oc get managedcluster`).
2. Each spoke must be named **`east`** and **`west`** (matching the folder names in the repository), and registered as Argo CD cluster secrets.
3. **`ManagedClusterSetBinding` `global`** exists in **`openshift-gitops`** and clusters carry **`cluster.open-cluster-management.io/clusterset: global`** (see chart templates).
4. **`Placement` `hub-spoke-placement`** selects your spokes (`region` in `east` | `west` by default).
5. **`PlacementDecision`** objects exist in **`openshift-gitops`** with decisions listing those cluster names:

   ```bash
   oc get placementdecisions.cluster.open-cluster-management.io -n openshift-gitops \
     -l cluster.open-cluster-management.io/placement=hub-spoke-placement -o yaml
   ```

6. **`GitOpsCluster` `hub-spoke-gitops`** is reconciled so Argo registers the same clusters (**Settings → Clusters** in Argo CD).
7. **RBAC**: Role **`applicationset-placementdecisions`** binds **`openshift-gitops-applicationset-controller`** so the **clusterDecisionResource** generator can **list** `placementdecisions`.
8. **Region paths exist**: `charts/region/east/` and `charts/region/west/` must contain bootstrap `Chart.yaml`, `values.yaml`, and `templates/` (same layout as hub).

## Step-by-step deployment

1. **Install OpenShift GitOps** on the hub (subscription stable channel) if not already present.
2. **Install ACM** hub components and verify `MultiClusterHub` is healthy.
3. **Create ManagedClusterSet** and bind hub + spokes.
4. **Label spokes** for placement (`region`, `environment`, etc.).
5. **Define Placement** and verify generated **PlacementDecision** objects show expected clusters.
6. **Create GitOpsCluster** referencing your Argo CD namespace (`openshift-gitops` by convention).
7. **Apply ApplicationSet** manifests (often shipped via this repo’s `acm-hub-spoke` chart path) so Applications appear under the Argo CD project.
8. **ACM console labels**: the ApplicationSet metadata must include `cluster.open-cluster-management.io/placement: hub-spoke-placement` (same value as the Placement label). Without it, ACM **Search → ApplicationSet → Details** may show *no Argo applications* even when `east-spoke-components` / `west-spoke-components` exist in `openshift-gitops`.
9. **Observe sync waves** — lower waves (namespaces, operators) complete before application workloads.
10. **Camel Dashboard (spokes):** after wave 3, verify `camel-dashboard-openshift-all-{east,west}` and enable the console plugin — see [Getting Started — Camel Dashboard](getting-started.md#camel-dashboard-east--west-spokes) and [Troubleshooting](troubleshooting.md).

If **`east-spoke-components`** or **`west-spoke-components`** is missing on the hub, re-sync `acm-hub-spoke`. The ApplicationSet `fleet-spoke-push` is a **persistent** resource in [`charts/all/acm-hub-spoke/templates/applicationset.yaml`](../../charts/all/acm-hub-spoke/templates/applicationset.yaml) (sync-wave `4`). Do not delete parent apps with `prune: true` unless you intend to recreate them.

For a full YAML walkthrough of each layer, see **[GitOps deployment chain](gitops-deployment-chain.md)**.

Verify from CLI (source of truth):

```bash
oc get applicationset fleet-spoke-push -n openshift-gitops -o jsonpath='{.status.resourcesCount}{"\n"}'
oc get applications -n openshift-gitops | grep spoke
```

## References

- [ACM Architecture — Welcome](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.16/html/about/welcome-to-red-hat-advanced-cluster-management-for-kubernetes)
- [Multicloud GitOps Validated Pattern](https://validatedpatterns.io/patterns/multicloud-gitops)
- [ApplicationSet Generators](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators/)

---

**Next →** [Scaffolding](scaffolding.md) to deploy Industrial Edge instances from Developer Hub, or [Getting Started](getting-started.md) for the full bootstrap walk-through.
