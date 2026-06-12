---
title: Region Strategy
weight: 9
---

# Region Strategy (single branch)

One git branch (`main`) serves hub, east, and west. Each cluster uses a **region path** in RHDP, not a separate git branch.

| Cluster | RHDP path | Values |
|---------|-----------|--------|
| Hub | `charts/region/hub` | `charts/region/hub/values.yaml` |
| East spoke | `charts/region/east` | `charts/region/east/values.yaml` |
| West spoke | `charts/region/west` | `charts/region/west/values.yaml` |

Shared component charts live under `charts/all/` and are referenced from each region's `clusterGroup.applications`.

## RHDP catalog

| Cluster | `gitops_repo_revision` | `gitops_repo_path` |
|---------|------------------------|--------------------|
| Hub | `main` | `charts/region/hub` |
| East | `main` | `charts/region/east` |
| West | `main` | `charts/region/west` |

Install on each cluster: RHDP field-content with `existing_gitops: true`, or `./pattern.sh install` with `TARGET_CLUSTERGROUP=hub|east|west`.

## PUSH + PULL on spokes

- **PUSH** (`operators-ci`, `operators-platform`): hub ApplicationSet `fleet-spoke-push`
- **PULL**: clustergroup on spoke from `charts/region/east|west/values.yaml`

See [GitOps PUSH vs PULL](gitops-push-vs-pull.md) and [REGIONS.md](../../REGIONS.md).
