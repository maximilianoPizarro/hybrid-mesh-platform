---
title: Argo CD AppProjects
nav_order: 4
parent: Hybrid Mesh Platform
---

# Argo CD AppProjects

Applications are grouped by **AppProject** for filtered views in OpenShift GitOps and to scope RBAC / allowed cluster resources per domain.

## Classification criteria

When adding a chart to `charts/region/*/values.yaml` → `clusterGroup.applications`, assign an AppProject using this order:

| Question | Project |
|----------|---------|
| Fleet membership, ACM, ApplicationSet parents? | `fleet`, `fleet-push`, or `fleet-pull` |
| OLM operators shared platform-wide (GitLab, Vault, ESO, ACM)? | `operators-platform` or `operators-ci` (PUSH spokes) / `operators-edge` (PULL spokes) |
| Security scanning, policy, AI governance (ACS, Kairos)? | `security` |
| Mesh, gateways, Skupper, RHCL / Kuadrant? | `mesh` |
| Metrics, logs, Kafka UI, cost? | `observability` |
| Learner-facing apps (RHDH, showroom, DevSpaces workload)? | `workshop` |
| Inference / chat workloads? | `ai` |
| Bootstrap namespaces, GitOps itself, platform users? | `platform` |
| External Secrets + Vault integration charts? | `external-secrets` |
| Industrial Edge factory stack (MQTT, Kafka, Camel, Tekton at edge)? | `industrial-edge` (spokes only) |

**PUSH vs PULL:** PUSH charts (`operators-ci`, `operators-platform`) use hub ApplicationSet projects (`fleet-push`, `operators-ci`). PULL charts use spoke-local projects (`industrial-edge`, `mesh`, …). See [GitOps PUSH vs PULL](gitops-push-vs-pull.md).

Regenerate AppProject layout after editing chart taxonomy:

```bash
python scripts/generate-vp-values.py
python scripts/apply-vp-argo-layout.py
```

## Hub projects

| Project | Examples |
|---------|----------|
| `platform` | namespaces, openshift-gitops, platform-users |
| `operators-platform` | operators-platform |
| `fleet` | acm-operator, acm-hub-spoke |
| `fleet-push` | ApplicationSet parents `*-spoke-components` |
| `fleet-pull` | fleet-pull-overview |
| `security` | acs-operator, kairos |
| `mesh` | servicemesh, rhcl, hub-gateway, neuroface-gateway, service-interconnect |
| `observability` | grafana, kiali, kafka-console, kubecost |
| `workshop` | developer-hub, showroom, gitlab-operator |
| `ai` | openshift-ai-hub, neuroface |
| `external-secrets` | vault, ESO |

## Spoke projects

| Project | Examples |
|---------|----------|
| `operators-ci` | operators-ci (PUSH only) |
| `operators-platform` | operators-platform (PUSH only) |
| `operators-edge` | AMQ, RHODS (PULL) |
| `industrial-edge` | IE tst, stormshift, pipelines |
| `mesh` | spoke-gateway, spoke-interconnect |
| `observability` | kiali, spoke-dashboards |
| `security` | acs-secured-cluster, kairos |
| `workshop` | devspaces workload, console-links |
