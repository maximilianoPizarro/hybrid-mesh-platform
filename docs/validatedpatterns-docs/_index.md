---
title: Hybrid Mesh Platform
nav_order: 2
layout: default
---

# Hybrid Mesh Platform

Hub-spoke multi-cluster GitOps on OpenShift — **Validated Patterns** implementation (Sandbox tier).

| Resource | URL |
|----------|-----|
| Pattern repo | [github.com/maximilianoPizarro/hybrid-mesh-platform](https://github.com/maximilianoPizarro/hybrid-mesh-platform) |
| GitHub Pages | [maximilianopizarro.github.io/hybrid-mesh-platform](https://maximilianopizarro.github.io/hybrid-mesh-platform/) |
| Workshop Showroom | [showroom-hybrid-mesh-ai](https://github.com/maximilianoPizarro/showroom-hybrid-mesh-ai) |

## Architecture

- **Hub:** ACM, clustergroup, Developer Hub, OpenShift AI, ACS Central, RHCL, Skupper listeners, observability
- **Spokes:** Industrial Edge, ACS Secured, ambient mesh, Skupper connectors, dual GitOps (PUSH + PULL)

## Repository structure

```
charts/
├── region/
│   ├── hub/        # Hub bootstrap + values
│   ├── east/       # East spoke bootstrap + values
│   └── west/       # West spoke bootstrap + values
└── all/            # 50+ shared Helm charts
```

## Documentation sections

### Getting started
- [Architecture](architecture.md)
- [Getting started](getting-started.md)
- [Region strategy](region-strategy.md)
- [RHDP field content](rhdp-field-content.md)

### GitOps strategy
- [PUSH vs PULL](gitops-push-vs-pull.md)
- [Argo AppProjects](argo-projects.md)
- [Deployment chain](gitops-deployment-chain.md)

### Components
- [Products index](products/index.md)
- [Service Interconnect](service-interconnect.md)
- [Industrial Edge](industrial-edge.md)
- [Observability](observability.md)
- [Hub Gateway](hub-gateway.md)

### Reference
- [Bill of Materials](../bill-of-materials.md)
- [Validation Guide](../validation-guide.md)
- [Annotations Reference](annotations-reference.md)
- [Troubleshooting](troubleshooting.md)

## Quick install

```bash
git clone https://github.com/maximilianoPizarro/hybrid-mesh-platform.git
cd hybrid-mesh-platform
cp values-secret.yaml.template values-secret.yaml
./pattern.sh make install
```

## Related patterns

- [Multicloud GitOps](https://validatedpatterns.io/patterns/multicloud-gitops/)
- [Industrial Edge](https://validatedpatterns.io/patterns/industrial-edge/)
