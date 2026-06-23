---
layout: default
title: Home
nav_order: 1
description: "Hybrid Mesh Platform — secure multi-cluster GitOps on OpenShift with ACM, Skupper, AI Computer Vision at the Edge, and optional Industrial Edge. Sandbox-tier Validated Pattern."
---

# Hybrid Mesh Platform

**One Git repo governs three OpenShift clusters** — secure connectivity, fleet GitOps, **AI Computer Vision at the Edge**, and optional factory telemetry across hub and spokes.

> **Primary demo (v2.2+):** NeuroFace full stack on **east/west spokes** — face detection (OVMS ModelMesh), PPE safety (YOLO/KServe), Kafka events, Grafana — federated via **Skupper** and **Gateway API 50/50** from the hub (`neuroface`, `neuroface-cv` routes).

> **Optional:** Industrial Edge (MQTT → Kafka → line-dashboard, sensors) is **disabled by default**. Uncomment IE apps in `charts/region/*/values.yaml` to enable.

**Multi-cluster GitOps** using Red Hat Advanced Cluster Management, OpenShift GitOps (Argo CD), ambient Service Mesh, Connectivity Link (Kuadrant), Skupper, Grafana, ACS, Developer Hub, and OpenShift AI.

## AI Computer Vision at the Edge (primary)

| Surface | URL | What it shows |
| ------- | --- | ------------- |
| NeuroFace app | `https://neuroface.<hub-domain>/` | Full UI — 50/50 east/west via hub Gateway |
| NeuroFace CV | `https://neuroface-cv.<hub-domain>/` | PPE gateway (YOLO on spokes) |
| Developer Hub | `https://developer-hub.<hub-domain>/create` | **AI Computer Vision at the Edge** template |
| Grafana | `https://grafana.<hub-domain>/` | NeuroFace east/west + hub gateway metrics |

Deep dive: [NeuroFace & CV journey](validatedpatterns-docs/products/neuroface.md) · [Workshop modules 13–16](validatedpatterns-docs/workshop/index.md)

## Quick links

| Topic | Page |
| ----- | ---- |
| Architecture | [Architecture](validatedpatterns-docs/architecture.md) |
| Install (ACM-first) | [Getting Started](validatedpatterns-docs/getting-started.md) |
| RHDP catalog orders | [RHDP field content](validatedpatterns-docs/rhdp-field-content.md) |
| Region paths (hub/east/west) | [Region strategy](validatedpatterns-docs/region-strategy.md) |
| ACM + GitOps | [Deploy with ACM and GitOps](validatedpatterns-docs/deploy-acm-gitops.md) |
| GitOps chain | [Deployment chain](validatedpatterns-docs/gitops-deployment-chain.md) |
| Fleet domain sync | [fleet-values-sync](validatedpatterns-docs/fleet-values-sync.md) |
| Secrets (`values-secret.yaml`) | [Secrets configuration](validatedpatterns-docs/secrets-configuration.md) |
| Red Hat products | [Products index](validatedpatterns-docs/products/index.md) |
| Scaffolding | [Scaffolding](validatedpatterns-docs/scaffolding.md) |
| Industrial Edge *(optional)* | [Industrial Edge](validatedpatterns-docs/industrial-edge.md) |
| Troubleshooting | [Troubleshooting](validatedpatterns-docs/troubleshooting.md) |
| **Workshop Showroom** | [Hybrid Mesh AI Workshop](validatedpatterns-docs/workshop/index.md) |

## Cluster sizing

| Role | Recommended | Minimum demo |
| ---- | ----------- | ------------ |
| **Hub** | 4 × 16 vCPU × 64 GiB | 3 × 8 × 32 GiB |
| **Spoke (CPU)** | 3 × 8 vCPU × 32 GiB | 2 × 4 × 16 GiB |
| **Spoke (GPU, optional)** | 3 × 8 vCPU × 32 GiB + 1× T4/A10G | — |

Full tables, workload budgets, and GPU operators: [Bill of Materials — Cluster sizing](bill-of-materials.md#cluster-sizing).

Verify: `bash scripts/verify-node-capacity.sh` · `ROLE=spoke bash scripts/verify-node-capacity.sh`

## Reference

| Topic | Page |
| ----- | ---- |
| Bill of Materials | [Operator versions](bill-of-materials.md) |
| Validation Guide | [Verify deployment](validation-guide.md) |
| Support Policy | [Community support](https://github.com/maximilianoPizarro/hybrid-mesh-platform/blob/main/SUPPORT.md) |

## Repository layout

| Path | Purpose |
| ---- | ------- |
| `charts/region/hub/` | Hub cluster bootstrap + clusterGroup values |
| `charts/region/east/` | East spoke bootstrap + clusterGroup values |
| `charts/region/west/` | West spoke bootstrap + clusterGroup values |
| `charts/all/` | Cross-cluster Helm charts (50+ charts) |
| `values-global.yaml` | Pattern-wide globals |
| `overrides/` | Platform-specific value overrides |
| `docs/` | GitHub Pages documentation |

## Key charts (default deploy)

| Chart | Purpose |
| ----- | ------- |
| `spoke-neuroface` | Full NeuroFace stack on spokes + OVMS ModelMesh + spoke Gateway |
| `spoke-neuroface-cv` | YOLO PPE InferenceService, Kafka, MinIO data path |
| `neuroface-gateway` | Hub routes 50/50 east/west + CV gateway |
| `acm-operator` | ACM MultiClusterHub installation |
| `acm-hub-spoke` | Spoke registration + GitOpsCluster |
| `developer-hub` | Catalog, software templates, scaffolder |
| `fleet-values-sync` | Cross-cluster domain sync |

Pattern repo: [github.com/maximilianoPizarro/hybrid-mesh-platform](https://github.com/maximilianoPizarro/hybrid-mesh-platform)

**Next →** [NeuroFace & AI CV](validatedpatterns-docs/products/neuroface.md)
