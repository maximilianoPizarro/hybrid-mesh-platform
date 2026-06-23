---
title: Bill of Materials
nav_order: 10
layout: default
---

# Bill of Materials

This document lists all Red Hat and community products/operators consumed by the Hybrid Mesh Platform pattern, along with their minimum versions and sources.

## OpenShift Platform

| Component | Minimum Version | Notes |
|-----------|-----------------|-------|
| OpenShift Container Platform | 4.16+ | Tested on 4.17-4.20 |
| OpenShift GitOps | 1.20+ | Installed via OperatorHub |

## Red Hat Operators (redhat-operators)

| Operator | Channel | Minimum Version | Purpose |
|----------|---------|-----------------|---------|
| Advanced Cluster Management (ACM) | release-2.16 | 2.16.x | Multi-cluster management, GitOps fleet |
| Red Hat Advanced Cluster Security (ACS) | stable | 4.7+ | Security scanning, policy enforcement |
| Red Hat OpenShift AI (RHOAI) | stable-3.4 | 3.4+ | ML/AI workloads, model serving (DSC API v2) |
| Red Hat Connectivity Link (RHCL) | stable | 1.4+ | API management, Kuadrant gateway |
| Red Hat Service Interconnect (Skupper) | stable-2 | 2.1+ | Multi-cluster service mesh |
| Red Hat OpenShift Serverless | stable | 1.35+ | Knative serving/eventing |
| Red Hat AMQ Streams (Kafka) | stable | 3.2+ | Event streaming |
| AMQ Streams Console | stable | 3.2+ | Kafka UI console |
| Red Hat OpenTelemetry | stable | 0.144+ | Distributed tracing collection |
| Tempo Operator | stable | 0.20+ | Trace storage backend |
| Red Hat Developer Hub (RHDH) | fast-1.9 | 1.9+ | Developer portal, Backstage |
| Red Hat Quay | stable-3.14 | 3.14+ | Container registry |
| OpenShift Virtualization (CNV) | stable | 4.20+ | VM workloads |
| Cluster Observability Operator | stable | 1.0+ | Unified monitoring |
| Kiali | stable | 2.22+ | Service mesh observability |
| OpenShift External Secrets | stable-v1 | 1.1+ | Secrets management |
| Red Hat OpenShift Dev Spaces | stable | 3.19+ | Cloud IDE |

## Community Operators (community-operators)

| Operator | Channel | Minimum Version | Purpose |
|----------|---------|-----------------|---------|
| Grafana Operator | v5 | 5.24+ | Dashboard provisioning |
| Camel K | stable-v2 | 2.10+ | Integration pipelines |
| GitLab Operator | stable | 8.9+ | Hub SCM (webservice, gitaly, registry) |
| GitLab Runner Operator | stable | 1.17+ | CI runners for Tekton/scaffolder pipelines |

## Helm Charts (External)

| Chart | Repository | Version | Purpose |
|-------|------------|---------|---------|
| clustergroup | charts.validatedpatterns.io | 0.9.* | VP framework bootstrap |
| hashicorp-vault | charts.validatedpatterns.io | 0.1.* | Secrets management |
| openshift-external-secrets | charts.validatedpatterns.io | 0.0.* | ESO configuration |
| gitlab-operator | OperatorHub (community) | stable | GitLab + Runner for scaffolder/Tekton |
| network-observer | quay.io/skupper/helm | 2.1.3 | Skupper network visualization |

## Industrial Edge Components

| Component | Source | Version | Purpose |
|-----------|--------|---------|---------|
| AMQ Broker | redhat-operators | 7.12.x | Message broker for edge |
| Kubernetes Image Puller | community-operators | stable | Pre-pull images on nodes |

## Validated Patterns Framework

| Component | Version | Source |
|-----------|---------|--------|
| common (Makefile-common) | main | github.com/validatedpatterns/common |
| clustergroup-chart | 0.9.* | charts.validatedpatterns.io |

## Version Compatibility Matrix

| OCP Version | ACM | ACS | RHOAI | Status |
|-------------|-----|-----|-------|--------|
| 4.20 | 2.16 | 4.7 | 3.4 | Tested |
| 4.17-4.19 | 2.15+ | 4.6+ | 3.4+ | Compatible |
| 4.16 | 2.14+ | 4.5+ | — | Minimum (OpenShift AI 3.4 requires 4.17+) |

## Notes

- All operators use Automatic install plan approval unless noted
- Channel versions follow semantic versioning where `stable-X.Y` pins to major.minor
- Community operators may have different support lifecycle than Red Hat operators
- For production deployments, pin specific versions in subscription manifests

## Cluster sizing

Sizing for **v2.2 AI CV at the Edge** (NeuroFace + OVMS ModelMesh + KServe YOLO on spokes). Industrial Edge optional and disabled by default.

### Hub (CPU-only)

| Tier | Workers | vCPU / worker | Memory / worker | Total alloc | Use case |
|------|---------|---------------|-----------------|-------------|----------|
| Recommended (workshop 30–50) | 4 | 16 | 64 GiB | 64 vCPU / 256 GiB | Full platform stack |
| Minimum demo (1–5 users) | 3 | 8 | 32 GiB | 24 vCPU / 96 GiB | Disable Kubecost/CNV under pressure |

Verify: `bash scripts/verify-node-capacity.sh` (hub 30: ≥16 CPU / 64 GiB; hub 50: ≥20 CPU / 80 GiB).

### Spokes — CPU-only (default)

| Tier | Workers | vCPU / worker | Memory / worker | Total alloc | Use case |
|------|---------|---------------|-----------------|-------------|----------|
| Recommended (AI CV + DevSpaces) | 3 | 8 | 32 GiB | 24 vCPU / 96 GiB | NeuroFace + OVMS + YOLO + DevSpaces |
| Minimum demo (AI CV only) | 2 | 4 | 16 GiB | 8 vCPU / 32 GiB | NeuroFace + OVMS only |

Verify: `ROLE=spoke bash scripts/verify-node-capacity.sh` (recommended: ≥24 CPU / 96 GiB; minimum: `SPOKE_TIER=minimum` ≥8 CPU / 32 GiB).

**Spoke CPU workload budget (approximate):**

| Component | CPU | Memory |
|-----------|-----|--------|
| OVMS ModelMesh (face detection) | 1 | 2 GiB |
| KServe YOLO PPE (HPA 1–4) | 0.2–2 | 1–3 GiB |
| NeuroFace app | 0.5 | 1 GiB |
| Kafka (cv-kafka) | 1 | 2 GiB |
| Skupper connectors | 0.2 | 0.5 GiB |
| ACS Secured Cluster | 0.5 | 1.5 GiB |
| Istio ambient + ztunnel | 0.3 | 0.5 GiB |
| DevSpaces (per workspace) | 1 | 2 GiB |
| Optional IE stack | +2 | +4 GiB |

### Spokes — GPU-accelerated (optional)

| Tier | Workers | vCPU / worker | Memory / worker | GPU / worker | Use case |
|------|---------|---------------|-----------------|--------------|----------|
| Recommended | 3 | 8 | 32 GiB | 1× T4 / A10G | OVMS GPU, YOLO GPU, vLLM 7B |
| Production-like | 3 | 16 | 64 GiB | 1× A100 (24+ GB VRAM) | Multi-model, LLM 14–70B |

**GPU VRAM budget:** OVMS ~2 GiB, YOLO ~2 GiB, vLLM 7B ~16 GiB, vLLM 14–70B ~24–80 GiB.

## GPU operators (optional)

Not installed by pattern default (CPU inference path). Required when GPU nodes are present.

### Required (install order)

| Operator | Channel | Catalog | Purpose |
|----------|---------|---------|---------|
| Node Feature Discovery (NFD) | stable | redhat-operators | Labels GPU nodes (`feature.node.kubernetes.io/pci-10de.present`) |
| NVIDIA GPU Operator | stable | certified-operators | Drivers, device plugin, DCGM, container toolkit |

### Optional

| Operator | Channel | Catalog | When needed |
|----------|---------|---------|-------------|
| NVIDIA Network Operator | stable | certified-operators | GPUDirect RDMA, multi-node training |
| OpenShift Serverless | stable | redhat-operators | Knative KServe (scale-to-zero on GPU) |
| NVIDIA NIM Operator | stable | certified-operators | NVIDIA NIM optimized LLM containers |

### Recommended cloud GPU instances

| Cloud | Instance | GPU | VRAM | Use case |
|-------|----------|-----|------|----------|
| AWS | g4dn.xlarge | 1× T4 | 16 GB | OVMS + YOLO demo |
| AWS | g5.2xlarge | 1× A10G | 24 GB | OVMS + YOLO + vLLM 7B |
| AWS | p4d.24xlarge | 8× A100 | 320 GB | Large LLM 70B+ |
| Azure | Standard_NC4as_T4_v3 | 1× T4 | 16 GB | Demo |
| Azure | Standard_NC24ads_A100_v4 | 1× A100 | 80 GB | Large LLM |
| GCP | a2-highgpu-1g | 1× A100 | 40 GB | Production inference |

**Verify GPU:** `CHECK_GPU=1 ROLE=spoke bash scripts/verify-node-capacity.sh`

## Updating Versions

To update operator versions:
1. Modify the `channel` field in `charts/region/{hub,east,west}/values.yaml`
2. For external Helm charts, update `chartVersion` in the application definition
3. Test in a non-production cluster before rolling out

## References

- [Red Hat Operators Lifecycle](https://access.redhat.com/support/policy/updates/openshift_operators)
- [Validated Patterns Framework](https://validatedpatterns.io)
- [ACM Supported Configurations](https://access.redhat.com/articles/7055998)
