---
layout: default
title: Home
nav_order: 1
---

# Hybrid Mesh Platform

> **Your journey:** Deploy hub + east + west on OpenShift via RHDP or `./pattern.sh install`, connect clusters with ACM and Skupper, and run Industrial Edge workloads from Developer Hub templates.

**Multi-cluster GitOps** using Red Hat Advanced Cluster Management, OpenShift GitOps (Argo CD), ambient Service Mesh, Connectivity Link (Kuadrant), Skupper, Grafana, ACS, Developer Hub, and Industrial Edge.

## Quick links

| Topic | Page |
| ----- | ---- |
| Architecture | [Architecture](validatedpatterns-docs/architecture.md) |
| Install (ACM-first) | [Getting Started](validatedpatterns-docs/getting-started.md) |
| RHDP catalog orders | [RHDP field content](validatedpatterns-docs/rhdp-field-content.md) |
| Region paths (hub/east/west) | [Region strategy](validatedpatterns-docs/region-strategy.md) |
| ACM + GitOps | [Deploy with ACM and GitOps](validatedpatterns-docs/deploy-acm-gitops.md) |
| GitOps chain | [Deployment chain](validatedpatterns-docs/gitops-deployment-chain.md) |
| Red Hat products | [Products index](validatedpatterns-docs/products/index.md) |
| Scaffolding | [Scaffolding](validatedpatterns-docs/scaffolding.md) |
| Troubleshooting | [Troubleshooting](validatedpatterns-docs/troubleshooting.md) |

## Repository layout

| Path | Purpose |
| ---- | ------- |
| `charts/all/` | Cross-cluster Helm components |
| `charts/region/hub\|east\|west/` | Per-cluster RHDP bootstrap + clusterGroup values |
| `values-global.yaml` | Pattern-wide globals |

Pattern repo: [github.com/maximilianoPizarro/hybrid-mesh-platform](https://github.com/maximilianoPizarro/hybrid-mesh-platform)

**Next →** [Architecture](validatedpatterns-docs/architecture.md)
