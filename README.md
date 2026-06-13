# Hybrid Mesh Platform

[![GitHub Pages](https://img.shields.io/badge/docs-GitHub%20Pages-blue)](https://maximilianopizarro.github.io/hybrid-mesh-platform/)
[![Validated Patterns](https://img.shields.io/badge/tier-Sandbox-yellow)](https://validatedpatterns.io)

Validated Patterns implementation of the Hybrid Mesh hub-spoke platform (forked from [multicloud-gitops](https://github.com/validatedpatterns/multicloud-gitops)).

**Documentation:** [maximilianopizarro.github.io/hybrid-mesh-platform](https://maximilianopizarro.github.io/hybrid-mesh-platform/)  
**Workshop Showroom:** [showroom-hybrid-mesh-ai](https://github.com/maximilianoPizarro/showroom-hybrid-mesh-ai)

## Why this pattern?

Enterprise teams need **secure multi-cluster connectivity**, **centralized GitOps**, and **edge + AI workloads** on OpenShift — without maintaining three independent control planes or site-to-site VPNs for every demo.

Hybrid Mesh Platform combines:

- **Hub-spoke fleet management** (ACM) with dual GitOps (PUSH ApplicationSet + PULL clustergroup per spoke)
- **Cross-cluster service connectivity** (Skupper VAN) so the hub reaches spoke Kafka, metrics, and gateways privately
- **Industrial Edge** factory telemetry (MQTT → Kafka → ML → dashboards) on east/west spokes
- **Centralized security and observability** (ACS Central, Grafana, Kafka Console on the hub)
- **Developer experience** (Developer Hub templates, OpenShift AI / MaaS, Gateway API ingress via RHCL/Kuadrant)

See the [architecture overview](docs/validatedpatterns-docs/architecture.md) for hub→spoke diagrams and a end-to-end sensor trace.

## What's included

| Component | What it does for you |
| --------- | -------------------- |
| **ACM + dual GitOps** | Fleet inventory, placement, PUSH operators + PULL IE/mesh per spoke |
| **Skupper** | Private TCP bridge hub ↔ spokes (Kafka Console, Grafana, hub-gateway) |
| **RHCL / Kuadrant** | Gateway API ingress with optional rate limits and API keys |
| **Industrial Edge** | MQTT, Camel K, Kafka, Tekton CI, anomaly ML at the edge |
| **OpenShift AI + MaaS** | Hub workbenches, model serving, external LLM via RHDP LiteMaaS |
| **ACS** | Central vulnerability and runtime policy across hub + spokes |
| **Developer Hub** | Catalog, scaffolding, multi-cluster topology, Tekton visibility |

Technical detail: 50+ Helm charts, decoupled Argo AppProjects (`operators-platform`, `industrial-edge`, `mesh`, `workshop`, `security`, …), ambient Service Mesh.

## Quick start

**Prerequisites**

- OpenShift **4.14+** (hub + two spokes recommended; see [Cluster sizing](#cluster-sizing))
- **`oc`** logged in as **cluster-admin** on the hub
- **Helm 3** and Git
- **RHDP workshop:** three separate catalog orders (hub, east, west) — see [RHDP field content](docs/validatedpatterns-docs/rhdp-field-content.md). Allow **60–90 minutes** for full fleet sync.
- **Standalone:** fork this repo, copy secrets template, run install below on the hub only; import spokes via ACM

```bash
# Clone and configure
git clone https://github.com/maximilianoPizarro/hybrid-mesh-platform.git
cd hybrid-mesh-platform
cp values-secret.yaml.template values-secret.yaml
# Edit values-secret.yaml if using external secrets / MaaS keys

# Install on hub cluster (bootstraps clustergroup + ACM ApplicationSet)
./pattern.sh make install
```

After install: register east/west in ACM, verify ApplicationSet `fleet-spoke-push`, then follow [Getting Started](docs/validatedpatterns-docs/getting-started.md).

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
| **Deployment chain** | [docs/validatedpatterns-docs/gitops-deployment-chain.md](docs/validatedpatterns-docs/gitops-deployment-chain.md) |
| **Products Index** | [docs/validatedpatterns-docs/products/index.md](docs/validatedpatterns-docs/products/index.md) |
| **Troubleshooting** | [docs/validatedpatterns-docs/troubleshooting.md](docs/validatedpatterns-docs/troubleshooting.md) |

## Support

This is a **Sandbox tier** Validated Pattern with community best-effort support.

See [SUPPORT.md](SUPPORT.md) for details.

## License

Apache License 2.0
