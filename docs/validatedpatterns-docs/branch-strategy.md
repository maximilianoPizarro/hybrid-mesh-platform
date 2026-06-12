---
title: Branch Strategy
weight: 9
---

# Branch Strategy (VP)

Three git branches map to three clusters. Each branch carries **one** clustergroup values file; shared charts stay under `charts/all/`.

| Branch | Cluster | `values-global.yaml` | Values file on branch |
|--------|---------|----------------------|------------------------|
| `main` | Hub | `clusterGroupName: hub` | `values-hub.yaml` (+ east/west for dev/generator) |
| `east` | East spoke | `clusterGroupName: east` | **`values-east.yaml` only** |
| `west` | West spoke | `clusterGroupName: west` | **`values-west.yaml` only** |

## RHDP catalog

| Cluster | `gitops_repo_revision` | `gitops_repo_path` |
|---------|------------------------|--------------------|
| Hub | `main` | `.` |
| East | `east` | `.` |
| West | `west` | `.` |

Install on each cluster: `./pattern.sh install` (utility container). Do not use legacy `east/` / `west/` Helm chart folders.

## Maintain spoke branches

On `main`, update `values-east.yaml` / `values-west.yaml`, commit, then:

```bash
bash scripts/sync-cluster-branches.sh
git push origin main east west
```

The script sets `clusterGroupName` on each branch, removes other `values-*.yaml` files from spoke branches, and commits.

## PUSH + PULL on spokes

- **PUSH** (`operators-ci`, `operators-platform`): hub ApplicationSet `fleet-spoke-push` (same on all branches; hub-only resource in git, deployed from hub)
- **PULL**: clustergroup on spoke from `values-east.yaml` or `values-west.yaml` on the matching branch

See [GitOps PUSH vs PULL](gitops-push-vs-pull.md).
