# Migration from platform-hub-spoke-config

This repository is the **Validated Patterns** implementation of the Hybrid Mesh Platform.

| Item | Location |
|------|----------|
| VP pattern (this repo) | `github.com/maximilianoPizarro/hybrid-mesh-platform` |
| Legacy App-of-Apps (frozen) | `github.com/maximilianoPizarro/platform-hub-spoke-config` |
| Workshop Showroom content | `github.com/maximilianoPizarro/showroom-hybrid-mesh-ai` |

## Architecture change

- **Before:** Custom Helm App-of-Apps (`templates/component-applications.yaml`) with hub-push ApplicationSet to spoke Argo CD.
- **After:** Validated Patterns `clustergroup` chart with ACM `managedClusterGroups` for **east** and **west** (pull model).

## Chart mapping

All legacy charts were copied from `platform-hub-spoke-config/components/*` to `charts/all/<name>/` without modifying the source repository.

Regenerate VP values after source changes:

```bash
python scripts/generate-vp-values.py
```

Source path (read-only): `../platform-hub-spoke-config`

## Cluster groups

| File | clusterGroup | Purpose |
|------|--------------|---------|
| `values-hub.yaml` | `hub` | ACM, GitOps, mesh, RHCL, AI, observability, demos |
| `values-east.yaml` | `east` | Industrial Edge workloads on east spoke |
| `values-west.yaml` | `west` | Same IE stack on west spoke |

## Secrets

Use `values-secret.yaml` (from `values-secret.yaml.template`) with Vault + External Secrets Operator per [VP secrets guide](https://validatedpatterns.io/learn/secrets-management-in-the-validated-patterns-framework/).

Legacy RHDP-injected secrets (`kairos-ai-credentials`, MaaS keys, spoke tokens) are documented in `values-secret.yaml.template`.

## Showroom cutover

Do **not** repoint the Showroom git-cloner until this pattern is validated on demo.redhat.com. The legacy repo continues to serve live workshops until cutover is announced.
