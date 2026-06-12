---
title: Hybrid Mesh Platform
weight: 1
---

# Hybrid Mesh Platform

Hub-spoke multi-cluster GitOps on OpenShift — **Validated Patterns** implementation.

| Resource | URL |
|----------|-----|
| Pattern repo | https://github.com/maximilianoPizarro/hybrid-mesh-platform |
| Legacy App-of-Apps | https://github.com/maximilianoPizarro/platform-hub-spoke-config |
| Showroom workshop | https://github.com/maximilianoPizarro/showroom-hybrid-mesh-ai |

## Architecture

- **Hub:** ACM, clustergroup, Developer Hub, OpenShift AI, ACS, RHCL, observability
- **Spokes:** Industrial Edge, ambient mesh, Skupper, dual GitOps (PUSH + PULL)

## Dual GitOps

- [PUSH vs PULL](gitops-push-vs-pull.md)
- [Argo AppProjects](argo-projects.md)
- [Deployment chain](gitops-deployment-chain.md)

## Install

```bash
./pattern.sh install
```

See [Getting started](getting-started.md), [Region strategy](region-strategy.md), and [RHDP field content](rhdp-field-content.md).

## Related patterns

- [Multicloud GitOps](https://validatedpatterns.io/patterns/multicloud-gitops/)
- [Industrial Edge](https://validatedpatterns.io/patterns/industrial-edge/)
