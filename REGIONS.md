# Region layout (single branch: `main`)

> **Note:** Git branches `east` and `west` were removed. All clusters use revision **`main`** and a region path below.

All clusters use git revision **`main`**. Per-cluster GitOps profile is selected by **RHDP path**, not by git branch.

| Cluster | RHDP `gitops_repo_path` | Values file |
|---------|-------------------------|-------------|
| Hub | `charts/region/hub` | `charts/region/hub/values.yaml` |
| East spoke | `charts/region/east` | `charts/region/east/values.yaml` |
| West spoke | `charts/region/west` | `charts/region/west/values.yaml` |

## Repository layout

```
charts/
  all/                 # Cross-cluster Helm components (shared)
  region/
    hub/               # Hub clusterGroup + RHDP bootstrap chart
    east/              # East spoke clusterGroup + bootstrap
    west/              # West spoke clusterGroup + bootstrap
    _shared/           # Canonical bootstrap template (copied to hub/east/west)
values-global.yaml     # Pattern-wide global + multiSourceConfig
```

Legacy root path `.` still works if RHDP sets `main.clusterGroupName` in helm values (defaults to `hub`).

## RHDP catalog (demo system)

| Parameter | Hub | East | West |
|-----------|-----|------|------|
| `gitops_repo_revision` | **`main`** | **`main`** | **`main`** |
| `gitops_repo_path` | **`charts/region/hub`** | **`charts/region/east`** | **`charts/region/west`** |
| `existing_gitops` | `true` | `true` | `true` |

See [RHDP field content](docs/validatedpatterns-docs/rhdp-field-content.md).

## Maintain region values

Edit `charts/region/{hub,east,west}/values.yaml` on `main`, commit, push. No branch sync script.

Regenerate from legacy source (optional):

```bash
python scripts/generate-vp-values.py
python scripts/apply-vp-argo-layout.py
```

After editing `_shared/templates/clustergroup-application.yaml`, copy to each region:

```bash
for r in hub east west; do
  cp charts/region/_shared/templates/clustergroup-application.yaml charts/region/$r/templates/
done
```
