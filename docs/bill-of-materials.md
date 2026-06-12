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
| Red Hat OpenShift AI (RHOAI) | stable-2.25 | 2.25+ | ML/AI workloads, model serving |
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

## Helm Charts (External)

| Chart | Repository | Version | Purpose |
|-------|------------|---------|---------|
| clustergroup | charts.validatedpatterns.io | 0.9.* | VP framework bootstrap |
| hashicorp-vault | charts.validatedpatterns.io | 0.1.* | Secrets management |
| openshift-external-secrets | charts.validatedpatterns.io | 0.0.* | ESO configuration |
| gitea | dl.gitea.com/charts | 12.5.0 | Git server for demos |
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
| 4.20 | 2.16 | 4.7 | 2.25 | Tested |
| 4.17-4.19 | 2.15+ | 4.6+ | 2.20+ | Compatible |
| 4.16 | 2.14+ | 4.5+ | 2.15+ | Minimum |

## Notes

- All operators use Automatic install plan approval unless noted
- Channel versions follow semantic versioning where `stable-X.Y` pins to major.minor
- Community operators may have different support lifecycle than Red Hat operators
- For production deployments, pin specific versions in subscription manifests

## Updating Versions

To update operator versions:
1. Modify the `channel` field in `charts/region/{hub,east,west}/values.yaml`
2. For external Helm charts, update `chartVersion` in the application definition
3. Test in a non-production cluster before rolling out

## References

- [Red Hat Operators Lifecycle](https://access.redhat.com/support/policy/updates/openshift_operators)
- [Validated Patterns Framework](https://validatedpatterns.io)
- [ACM Supported Configurations](https://access.redhat.com/articles/7055998)
