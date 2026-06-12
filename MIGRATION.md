# Migration from platform-hub-spoke-config

Validated Patterns implementation: `github.com/maximilianoPizarro/hybrid-mesh-platform`

| Item | Location |
|------|----------|
| VP pattern (this repository) | `hybrid-mesh-platform` |
| Legacy App-of-Apps (frozen) | `platform-hub-spoke-config` |
| Workshop Showroom | `showroom-hybrid-mesh-ai` |

## Architecture change

| Before (legacy) | After (VP) |
|-----------------|------------|
| Root Helm chart `.` + `east/` / `west/` | `charts/region/{hub,east,west}/` + `charts/all/*` |
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
| `generate-vp-values.py` | Legacy → `charts/region/{hub,east,west}/values.yaml` |
| `apply-vp-argo-layout.py` | AppProject taxonomy |
| `verify-gitops-strategies.py` | PUSH/PULL partition check |
| `argocd-preflight.sh` | CI preflight |
| `split-chart-templates.py` | Split all.yaml (safe for static docs) |

## Regions (single branch: `main`)

| RHDP path | Cluster | Values |
|-----------|---------|--------|
| `charts/region/hub` | hub | `charts/region/hub/values.yaml` |
| `charts/region/east` | east | `charts/region/east/values.yaml` |
| `charts/region/west` | west | `charts/region/west/values.yaml` |

See [REGIONS.md](REGIONS.md).

## Showroom cutover

Do not repoint Showroom git-cloner until `./pattern.sh install` is validated on RHDP.
