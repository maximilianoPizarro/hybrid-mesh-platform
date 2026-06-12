# Region layout design (2026-06-12)

## Goal

Single git branch (`main`) for hub, east, and west. RHDP demo system selects cluster profile by **path**, not git branch.

## Layout

- `charts/all/` — cross-cluster Helm components (unchanged)
- `charts/region/hub|east|west/` — per-cluster bootstrap chart + `values.yaml` (clusterGroup)
- `values-global.yaml` — pattern-wide globals + multiSourceConfig only

## RHDP catalog

| Cluster | revision | path |
|---------|----------|------|
| Hub | `main` | `charts/region/hub` |
| East | `main` | `charts/region/east` |
| West | `main` | `charts/region/west` |

## Removed (2026-06)

- Git branches `east` / `west` — use `main` + region paths only
- Root `values-hub.yaml`, `values-east.yaml`, `values-west.yaml`
- `scripts/sync-cluster-branches.sh`, `BRANCHES.md`

## Bootstrap flow

1. RHDP creates `field-content` Application pointing at region path
2. Region chart renders `hybrid-mesh-platform-{region}` Application
3. Clustergroup multisource loads `values-global.yaml` + `charts/region/{region}/values.yaml`
4. Child apps reference `charts/all/*` paths
