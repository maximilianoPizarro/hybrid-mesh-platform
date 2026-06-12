# Cluster branch: main (hub)

| Branch | Cluster | Values file |
|--------|---------|-------------|
| `main` | Hub | `values-hub.yaml` |
| `east` | East spoke | `values-east.yaml` only |
| `west` | West spoke | `values-west.yaml` only |

Create/update spoke branches:

```bash
scripts/sync-cluster-branches.sh
```
