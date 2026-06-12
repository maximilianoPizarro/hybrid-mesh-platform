# Cluster branch: main (hub)

| Branch | Cluster | Values file |
|--------|---------|-------------|
| `main` | Hub | `values-hub.yaml` |
| `east` | East spoke | `values-east.yaml` only |
| `west` | West spoke | `values-west.yaml` only |

RHDP / catalog: use the **same repo URL** with different **revision** (branch) on each cluster order. Path is always `.` (repo root); VP selects the clustergroup via `values-global.yaml` on that branch.

```bash
# After editing values on main:
python scripts/generate-vp-values.py      # optional, from legacy
python scripts/apply-vp-argo-layout.py
git add values-*.yaml && git commit -m "update cluster values"
bash scripts/sync-cluster-branches.sh     # propagates to east/west branches
```
