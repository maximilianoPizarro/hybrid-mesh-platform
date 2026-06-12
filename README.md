# Hybrid Mesh Platform

Validated Patterns implementation of the Hybrid Mesh hub-spoke platform (forked from [multicloud-gitops](https://github.com/validatedpatterns/multicloud-gitops)).

**Legacy repo (frozen):** [platform-hub-spoke-config](https://github.com/maximilianoPizarro/platform-hub-spoke-config)  
**Workshop Showroom:** [showroom-hybrid-mesh-ai](https://github.com/maximilianoPizarro/showroom-hybrid-mesh-ai)

## What's included

- **Dual GitOps:** PUSH (`fleet-spoke-push` ApplicationSet) + PULL (ACM `managedClusterGroups`)
- ACM fleet (east/west) via `charts/all/acm-hub-spoke`
- Decoupled Argo AppProjects: `operators-ci`, `industrial-edge`, `mesh`, `workshop`, …
- Ambient Service Mesh, Skupper, RHCL/Kuadrant, Industrial Edge, OpenShift AI, ACS, Developer Hub

See [MIGRATION.md](MIGRATION.md) and [docs/validatedpatterns-docs/](docs/validatedpatterns-docs/).

## Quick start

```bash
cp values-secret.yaml.template values-secret.yaml
# Edit secrets (Vault / RHDP tokens)

./pattern.sh install
```

| Values file | Cluster group |
|-------------|---------------|
| `values-hub.yaml` | Hub |
| `values-east.yaml` | East spoke (PULL) |
| `values-west.yaml` | West spoke (PULL) |

PUSH operators (`operators-ci`, `operators-platform`) deploy via ApplicationSet to both spokes.

## Regenerate values

```bash
python scripts/generate-vp-values.py
python scripts/apply-vp-argo-layout.py
bash scripts/sync-cluster-branches.sh   # east/west branches from main
```

## Branch strategy

| Branch | Cluster | Values |
|--------|---------|--------|
| `main` | Hub | `values-hub.yaml` |
| `east` | East spoke | `values-east.yaml` only |
| `west` | West spoke | `values-west.yaml` only |

See [BRANCHES.md](BRANCHES.md) and [branch strategy](docs/validatedpatterns-docs/branch-strategy.md).

## Verification (offline)

```bash
bash scripts/argocd-preflight.sh
python scripts/verify-gitops-strategies.py
bash scripts/verify-fleet.sh             # requires live cluster
```

## Cluster sizing (hub)

| Parameter | Recommended | Minimum |
|-----------|-------------|---------|
| Workers | 3 × 8 vCPU × 32 GiB | 3 × 4 vCPU × 16 GiB |
| OpenShift | 4.20 | 4.17+ |

Spokes: 3 × 4 vCPU × 16 GiB (8 GiB OK for demo IE stack).

## Documentation

- [Validated Patterns — Hybrid Mesh Platform](https://validatedpatterns.io/patterns/hybrid-mesh-platform/)
- [GitOps PUSH vs PULL](docs/validatedpatterns-docs/gitops-push-vs-pull.md)
- [Argo AppProjects](docs/validatedpatterns-docs/argo-projects.md)
- PR body template: [docs/validatedpatterns-docs/README.md](docs/validatedpatterns-docs/README.md)
