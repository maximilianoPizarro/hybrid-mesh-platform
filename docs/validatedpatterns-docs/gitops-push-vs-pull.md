---
title: GitOps PUSH vs PULL
nav_order: 3
parent: Hybrid Mesh Platform
---

# GitOps PUSH vs PULL (dual strategy)

Hybrid Mesh Platform runs **both** fleet GitOps strategies on east and west spokes, with **partitioned workloads** to avoid duplicate resources.

## Strategy comparison

| | PUSH (hub ApplicationSet) | PULL (ACM managedClusterGroups) |
|--|---------------------------|----------------------------------|
| **Mechanism** | `fleet-spoke-push` ApplicationSet on hub | VP `clustergroup` on each spoke via ACM |
| **Argo project** | `fleet-push`, `operators-ci`, `operators-platform` | `industrial-edge`, `mesh`, `observability`, `operators-edge`, … |
| **Charts** | `operators-ci`, `operators-platform` | IE stack, mesh, gateways, observability, `operators-edge` |
| **Where to look (hub)** | ApplicationSets → `fleet-spoke-push`; Apps → `east-spoke-components` | App `fleet-pull-overview`; ACM Fleet Applications |
| **Where to look (spoke)** | Filter `platform.io/gitops-strategy=push` | Clustergroup root + domain AppProjects |

## Workload partition

```yaml
# values in acm-hub-spoke chart
gitops:
  strategies:
    push:
      componentIds:
        - operators-ci
        - operators-platform
    pull:
      enabled: true
```

PUSH deploys Tekton, Camel K, DevSpaces operator, and platform OLM subs. PULL deploys Industrial Edge, mesh, observability, and `operators-edge` (AMQ, RHODS).

## Verify

```bash
# Hub — PUSH chain
oc get applicationset fleet-spoke-push -n openshift-gitops
oc get applications -n openshift-gitops -l platform.io/gitops-strategy=push

# Spoke — both chains
oc get applications -n openshift-gitops | grep -E 'operators-ci|industrial-edge'
python scripts/verify-gitops-strategies.py
```

See also [GitOps deployment chain](gitops-deployment-chain.md) and [Argo projects](argo-projects.md).
