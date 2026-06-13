# Hybrid Mesh Platform — documentation index

Hub-spoke multi-cluster GitOps on OpenShift. **Sandbox tier** Validated Pattern.

| Resource | URL |
|----------|-----|
| Pattern repo | [github.com/maximilianoPizarro/hybrid-mesh-platform](https://github.com/maximilianoPizarro/hybrid-mesh-platform) |
| GitHub Pages | [maximilianopizarro.github.io/hybrid-mesh-platform](https://maximilianopizarro.github.io/hybrid-mesh-platform/) |
| Workshop Showroom | [showroom-hybrid-mesh-ai](https://github.com/maximilianoPizarro/showroom-hybrid-mesh-ai) |

## Getting started

| Topic | File |
|-------|------|
| Architecture overview | [architecture.md](architecture.md) |
| Install (ACM-first) | [getting-started.md](getting-started.md) |
| RHDP catalog (3 cluster orders) | [rhdp-field-content.md](rhdp-field-content.md) |
| Region paths (hub / east / west) | [region-strategy.md](region-strategy.md) |
| Deploy with ACM + GitOps | [deploy-acm-gitops.md](deploy-acm-gitops.md) |

## GitOps strategy

| Topic | File |
|-------|------|
| PUSH vs PULL (dual strategy) | [gitops-push-vs-pull.md](gitops-push-vs-pull.md) |
| End-to-end deployment chain | [gitops-deployment-chain.md](gitops-deployment-chain.md) |
| Argo CD AppProjects | [argo-projects.md](argo-projects.md) |

## Components & products

| Topic | File |
|-------|------|
| Red Hat products index | [products/index.md](products/index.md) |
| Service Interconnect (Skupper) | [service-interconnect.md](service-interconnect.md) |
| Industrial Edge | [industrial-edge.md](industrial-edge.md) |
| Hub Gateway (Gateway API) | [hub-gateway.md](hub-gateway.md) |
| Observability | [observability.md](observability.md) |
| Scaffolding new edge instances | [scaffolding.md](scaffolding.md) |

## Reference

| Topic | File |
|-------|------|
| Bill of Materials | [../bill-of-materials.md](../bill-of-materials.md) |
| Validation Guide | [../validation-guide.md](../validation-guide.md) |
| Annotations & labels | [annotations-reference.md](annotations-reference.md) |
| Troubleshooting | [troubleshooting.md](troubleshooting.md) |

## Maintainer note

To publish on [validatedpatterns.io](https://validatedpatterns.io), copy this folder into `validatedpatterns/docs/content/patterns/hybrid-mesh-platform/` and update front matter `repo_url` links. The public site index is [_index.md](_index.md).
