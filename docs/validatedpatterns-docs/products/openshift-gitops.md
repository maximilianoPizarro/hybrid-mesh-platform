---
title: Openshift Gitops
weight: 28
---

# OpenShift GitOps

**Git path:** `charts/all/openshift-gitops/`
{: .fs-3 .text-grey-dk-000 }

Red Hat **OpenShift GitOps** delivers **Argo CD** as an operator-managed control plane for declarative Git-driven deployments on OpenShift.

![Argo CD – Login]({{ site.baseurl }}/assets/images/product-argocd-openshift-gitops.png)
{: .mb-4 }
*Argo CD login page with OpenShift SSO integration.*
{: .fs-2 .text-grey-dk-000 }

## Operator discovery

OpenShift GitOps ships classic **`Application`** / **`ApplicationSet`** / **`AppProject`** CRDs scoped namespaces **`openshift-gitops`** (or custom installs).

Operators reconcile Git manifests referenced via **`spec.source.repoURL`** plus Helm overlays — nothing analogous exists inside workload **`Deployments`** beyond **`argocd.argoproj.io/***` annotations Argo injects **after** sync for drift tooling (**those annotations advertise GitOps ownership**, they **do not** trigger enrollment).

## Patterns in this repository

| Pattern | Description |
| ------- | ----------- |
| **Argo CD** | Pull-based reconciliation from Git; UI and CLI on the hub. |
| **App-of-Apps** | Root `Application` (or Helm-generated Applications) owns child Applications per component. |
| **ApplicationSet** | Fleet-scale fan-out using generators (for example cluster × chart with ACM). |

## Helm integration

The parent chart under repository root renders **Argo CD `Application`** manifests from `connectivityLink.apps[]`, preserving sync waves and ignore differences for OpenShift routes and secrets.

## References

- [OpenShift GitOps overview](https://docs.redhat.com/en/documentation/openshift_gitops/)
- [Argo CD documentation](https://argo-cd.readthedocs.io/)
