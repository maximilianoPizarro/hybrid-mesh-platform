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

## Reference

| Topic | Page |
| ----- | ---- |
| Bill of Materials | [Operator versions](bill-of-materials.md) |
| Validation Guide | [Verify deployment](validation-guide.md) |
| Support Policy | [Community support](../SUPPORT.md) |

## Repository layout

| Path | Purpose |
| ---- | ------- |
| `charts/region/hub/` | Hub cluster bootstrap + clusterGroup values |
| `charts/region/east/` | East spoke bootstrap + clusterGroup values |
| `charts/region/west/` | West spoke bootstrap + clusterGroup values |
| `charts/all/` | Cross-cluster Helm components (50+ charts) |
| `values-global.yaml` | Pattern-wide globals |
| `overrides/` | Platform-specific value overrides |
| `docs/` | GitHub Pages documentation |

## Key charts

| Chart | Purpose |
| ----- | ------- |
| `acm-operator` | ACM MultiClusterHub installation |
| `acm-hub-spoke` | Spoke registration + GitOpsCluster |
| `console-links` | OpenShift Console quick links |
| `platform-validation` | Automated validation CronJobs |
| `fleet-values-sync` | Cross-cluster domain sync |

Pattern repo: [github.com/maximilianoPizarro/hybrid-mesh-platform](https://github.com/maximilianoPizarro/hybrid-mesh-platform)

**Next →** [Architecture](validatedpatterns-docs/architecture.md)
