---
title: Pipelines
weight: 29
---

# OpenShift Pipelines

**Git path:** `charts/all/industrial-edge-pipelines/`
{: .fs-3 .text-grey-dk-000 }

Red Hat **OpenShift Pipelines** delivers **Tekton** CRDs for CI/CD native to Kubernetes — ideal for building container images, running tests, and promoting Industrial Edge artifacts across environments.

## Industrial Edge CI/CD

- Tekton `Pipeline` and `PipelineRun` objects live alongside GitOps-managed workloads.
- Integration with corporate registries and signing flows stays outside this chart but hooks cleanly via workspaces and secrets.

## Operator discovery

**OpenShift Pipelines operator** watches **`TektonConfig`** / **`TektonPipeline`** / **`TektonTrigger`** cluster-scope CRs — controllers automatically provision Tekton controllers (`tekton-pipelines-controller`, …) and webhook deployments **without per-namespace enrollment annotations**.

Namespaces become usable once **`Pipeline`** / **`PipelineRun`** CRDs apply there — RBAC ServiceAccounts supply credentials GitOps charts attach.

## Documentation

- [OpenShift Pipelines documentation](https://docs.redhat.com/en/documentation/openshift_pipelines/)

Component chart: `charts/all/industrial-edge-pipelines`.
