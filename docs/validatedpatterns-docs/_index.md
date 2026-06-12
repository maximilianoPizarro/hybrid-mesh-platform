---
title: Hybrid Mesh Platform
weight: 1
---

# Hybrid Mesh Platform

Hub-spoke multi-cluster GitOps on OpenShift — **Validated Patterns** implementation.

| Resource | URL |
|----------|-----|
| Pattern repo | https://github.com/maximilianoPizarro/hybrid-mesh-platform |
| Legacy App-of-Apps (workshop) | https://github.com/maximilianoPizarro/platform-hub-spoke-config |
| Showroom workshop | https://github.com/maximilianoPizarro/showroom-hybrid-mesh-ai |

## Architecture

- **Hub:** ACM, OpenShift GitOps (clustergroup), Developer Hub, OpenShift AI, ACS Central, RHCL/Kuadrant, hub gateway, observability
- **Spokes (east/west):** Industrial Edge, ambient mesh, Skupper, ACS SecuredCluster, DevSpaces

This pattern uses the Validated Patterns framework (`clustergroup`, Vault + External Secrets, ACM managedClusterGroups).

## Install

See the [pattern repository README](https://github.com/maximilianoPizarro/hybrid-mesh-platform/blob/main/README.md).

```bash
./pattern.sh install
```

## Related patterns

- [Multicloud GitOps](https://validatedpatterns.io/patterns/multicloud-gitops/) — base fork
- [Industrial Edge](https://validatedpatterns.io/patterns/industrial-edge/) — IE workload reference
