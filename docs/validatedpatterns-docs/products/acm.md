---
title: Acm
weight: 15
---

# Advanced Cluster Management

**Git path:** `charts/all/acm-hub-spoke/`
{: .fs-3 .text-grey-dk-000 }

## What problem does it solve?

Running GitOps on three clusters with Argo CD alone means three independent control planes, manual cluster registration, and no fleet-wide policy. **ACM** gives you a single inventory of hub + spokes, dynamic **Placement** (which clusters get which workloads), and **ManifestWork** for hub-initiated changes — without opening VPNs or sharing kubeconfigs in Git.

In this pattern ACM is not optional decoration: it drives **PULL** GitOps via VP `managedClusterGroups`, creates **PlacementDecisions** that feed the **`fleet-spoke-push`** ApplicationSet, and runs **ManagedClusterAction** jobs (Skupper token sync, ACS init bundles, fleet domain patching).

## Why ACM and not only Argo ApplicationSet?

| Capability | Argo ApplicationSet alone | ACM + ApplicationSet (this pattern) |
| ---------- | ------------------------- | ------------------------------------- |
| Cluster inventory | Manual `Secret` per cluster | **`ManagedCluster`** auto-import |
| Dynamic cluster selection | Static list or cluster generator | **`Placement`** + **`PlacementDecision`** (label `region: east\|west`) |
| Policy / compliance | Not built-in | **`Policy`** + **`PolicyReport`** across fleet |
| Hub → spoke actions | Limited to Git-synced apps | **`ManifestWork`**, **`ManagedClusterAction`**, addons |
| Spoke-local GitOps | Separate bootstrap per cluster | VP **clustergroup** on each spoke via **managedClusterGroups** |

**ApplicationSet** (`fleet-spoke-push`) handles **PUSH** — a narrow set of operator charts pushed from the hub. **managedClusterGroups** handle **PULL** — Industrial Edge, mesh, observability — where each spoke's local Argo CD reconciles its own `charts/region/east|west/values.yaml`. ACM is the glue that knows which clusters exist and which strategy applies where.

Red Hat **Advanced Cluster Management for Kubernetes (ACM)** provides fleet-wide visibility and lifecycle for OpenShift and Kubernetes clusters. In this repository it anchors **hub-spoke registration**, **policy placement**, and integration with **OpenShift GitOps** via `GitOpsCluster` and related APIs.

![ACM Fleet Management]({{ site.baseurl }}/assets/images/ACM.png)
{: .mb-4 }
*ACM Fleet Management — east and west managed clusters registered on the hub.*
{: .fs-2 .text-grey-dk-000 }

## Role in this solution

- Inventory managed clusters and apply governance policies consistently.
- Drive **which spokes** receive Industrial Edge and platform components through placement rules.
- Coordinate secrets and addons required for klusterlet agents on spokes.

## Notable APIs / CRDs (overview)

Typical objects you will encounter:

- `MultiClusterHub` — hub installation status.
- `ManagedCluster`, `ManagedClusterSet` — membership grouping.
- `Placement`, `PlacementDecision` — dynamic cluster selection.
- `GitOpsCluster` — binds placement results to Argo CD managed clusters.

Install specifics live in the `acm-operator` and `acm-hub-spoke` component charts in `components/`.

## Operator discovery

ACM controllers reconcile **`ManagedCluster`**, **`ManagedClusterSet`**, **`Placement`**, **`PlacementDecision`**, **`ManifestWork`**, and **`GitOpsCluster`** APIs directly against etcd — **`Deployments do not carry ACM annotations`** for fleet enrollment.

Imported spokes inherit **`ManagedCluster`** metadata (`labels.annotations`), **`ManagedClusterSet` bindings**, and feature-addon statuses driven by **`ManagedClusterAddon`** controllers — inspect hub namespaces **`open-cluster-management*`**, **`openshift-gitops`**, and cluster-scope **`managedcluster`** objects (`oc get managedcluster`) rather than hunting workload namespaces.

## Documentation

- [Red Hat ACM 2.16 documentation](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.16)
