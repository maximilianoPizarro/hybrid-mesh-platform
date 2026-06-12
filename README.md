# Hybrid Mesh Platform

[![GitHub Pages](https://img.shields.io/badge/docs-GitHub%20Pages-blue)](https://maximilianopizarro.github.io/hybrid-mesh-platform/)
[![Validated Patterns](https://img.shields.io/badge/tier-Sandbox-yellow)](https://validatedpatterns.io)

Validated Patterns implementation of the Hybrid Mesh hub-spoke platform (forked from [multicloud-gitops](https://github.com/validatedpatterns/multicloud-gitops)).

**Documentation:** [maximilianopizarro.github.io/hybrid-mesh-platform](https://maximilianopizarro.github.io/hybrid-mesh-platform/)  
**Workshop Showroom:** [showroom-hybrid-mesh-ai](https://github.com/maximilianoPizarro/showroom-hybrid-mesh-ai)

## What's included

- **Dual GitOps:** PUSH (`fleet-spoke-push` ApplicationSet) + PULL (ACM `managedClusterGroups`)
- **ACM fleet management** with auto-import via `charts/all/acm-hub-spoke`
- **50+ Helm charts** for hub and spoke components
- Decoupled Argo AppProjects: `operators-platform`, `industrial-edge`, `mesh`, `workshop`, `security`, …
- Ambient Service Mesh, Skupper, RHCL/Kuadrant, Industrial Edge, OpenShift AI, ACS, Developer Hub

## Quick start

```bash
# Clone and configure
git clone https://github.com/maximilianoPizarro/hybrid-mesh-platform.git
cd hybrid-mesh-platform
cp values-secret.yaml.template values-secret.yaml

# Install on hub cluster
./pattern.sh make install
```

## Repository structure

```
hybrid-mesh-platform/
├── charts/
│   ├── region/           # Bootstrap per cluster role
│   │   ├── hub/          # Hub (ACM, RHDH, ACS Central)
│   │   ├── east/         # East spoke (IE, ACS Secured)
│   │   └── west/         # West spoke (IE, ACS Secured)
│   └── all/              # 50+ shared Helm charts
├── docs/                 # GitHub Pages documentation
├── overrides/            # Platform-specific values
├── scripts/              # Utility scripts
├── values-global.yaml    # Pattern-wide globals
└── pattern.sh            # VP framework bootstrap
```

## Region strategy (single branch: `main`)

| Cluster | Bootstrap Path | Description |
|---------|----------------|-------------|
| **Hub** | `charts/region/hub` | ACM, Developer Hub, ACS Central, Gitea, Quay |
| **East** | `charts/region/east` | Industrial Edge, ACS Secured, Skupper |
| **West** | `charts/region/west` | Industrial Edge, ACS Secured, Skupper |

See [Region Strategy](docs/validatedpatterns-docs/region-strategy.md) for details.

## Cluster sizing

| Role | Workers | vCPU | Memory | OpenShift |
|------|---------|------|--------|-----------|
| Hub | 3+ | 8 | 32 GiB | 4.17+ |
| Spoke | 3+ | 4 | 16 GiB | 4.17+ |

## Verification

```bash
# Offline validation
bash scripts/argocd-preflight.sh
python scripts/verify-gitops-strategies.py

# Live cluster validation
bash scripts/verify-fleet.sh
```

## Documentation

| Topic | Link |
|-------|------|
| **Architecture** | [docs/validatedpatterns-docs/architecture.md](docs/validatedpatterns-docs/architecture.md) |
| **Getting Started** | [docs/validatedpatterns-docs/getting-started.md](docs/validatedpatterns-docs/getting-started.md) |
| **Bill of Materials** | [docs/bill-of-materials.md](docs/bill-of-materials.md) |
| **Validation Guide** | [docs/validation-guide.md](docs/validation-guide.md) |
| **GitOps Strategy** | [docs/validatedpatterns-docs/gitops-push-vs-pull.md](docs/validatedpatterns-docs/gitops-push-vs-pull.md) |
| **Products Index** | [docs/validatedpatterns-docs/products/index.md](docs/validatedpatterns-docs/products/index.md) |
| **Troubleshooting** | [docs/validatedpatterns-docs/troubleshooting.md](docs/validatedpatterns-docs/troubleshooting.md) |

## Support

This is a **Sandbox tier** Validated Pattern with community best-effort support.

See [SUPPORT.md](SUPPORT.md) for details.

## License

Apache License 2.0
