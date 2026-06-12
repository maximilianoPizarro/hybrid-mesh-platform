# Migration from platform-hub-spoke-config

Validated Patterns implementation: `github.com/maximilianoPizarro/hybrid-mesh-platform`

| Item | Location |
|------|----------|
| VP pattern (this repo) | `hybrid-mesh-platform` |
| Legacy App-of-Apps (frozen) | `platform-hub-spoke-config` |
| Workshop Showroom | `showroom-hybrid-mesh-ai` |

## Architecture change

| Before (legacy) | After (VP) |
|-----------------|------------|
| Root Helm chart `.` + `east/` / `west/` | `values-{hub,east,west}.yaml` + `charts/all/*` |
| ApplicationSet `industrial-edge-spoke` only | **Dual:** `fleet-spoke-push` (PUSH) + `managedClusterGroups` (PULL) |
| Single Argo project `default` / `hub` | Domain AppProjects (`operators-ci`, `industrial-edge`, …) |
| Monolithic `operators` chart | `operators-ci`, `operators-platform`, `operators-edge` |

## Dual GitOps partition

| Strategy | Spoke apps | Mechanism |
|----------|------------|-----------|
| **PUSH** | `operators-ci`, `operators-platform` | Hub ApplicationSet → `spoke-meta-push` |
| **PULL** | IE, mesh, observability, `operators-edge`, … | ACM clustergroup on spoke |

## Chart mapping

```
platform-hub-spoke-config/components/<name>/  →  charts/all/<name>/
```

19 charts use split templates; 11 templated charts retain `all.yaml` (Helm `range` blocks).

## Doc mapping

| Legacy | VP |
|--------|-----|
| `docs/getting-started.md` | `docs/validatedpatterns-docs/getting-started.md` |
| `docs/gitops-deployment-chain.md` | same path under validatedpatterns-docs |
| GitHub Pages | validatedpatterns.io |

Regenerate: `python scripts/migrate-docs-vp.py`

## Scripts

| Script | Purpose |
|--------|---------|
| `generate-vp-values.py` | Legacy → values-hub/east/west |
| `apply-vp-argo-layout.py` | AppProject taxonomy |
| `verify-gitops-strategies.py` | PUSH/PULL partition check |
| `argocd-preflight.sh` | CI preflight |
| `split-chart-templates.py` | Split all.yaml (safe for static docs) |
| `sync-cluster-branches.sh` | Propagate `east`/`west` branches from main |

## Cluster branches

| Branch | Cluster | Values on branch |
|--------|---------|------------------|
| `main` | hub | `values-hub.yaml` (+ east/west for dev) |
| `east` | east | `values-east.yaml` only |
| `west` | west | `values-west.yaml` only |

```bash
bash scripts/sync-cluster-branches.sh
```

## Showroom cutover

Do not repoint Showroom git-cloner until `./pattern.sh install` is validated on RHDP.
