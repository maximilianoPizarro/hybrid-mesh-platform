---
title: Acm
weight: 15
---

# Advanced Cluster Management

**Git path:** `charts/all/acm-hub-spoke/`
{: .fs-3 .text-grey-dk-000 }

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
