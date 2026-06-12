---
title: Argo CD AppProjects
weight: 5
---

# Argo CD AppProjects

Applications are grouped by **AppProject** for filtered views in OpenShift GitOps.

## Hub projects

| Project | Examples |
|---------|----------|
| `platform` | namespaces, openshift-gitops, platform-users |
| `operators-platform` | operators-platform |
| `fleet` | acm-operator, acm-hub-spoke |
| `fleet-push` | ApplicationSet parents `*-spoke-components` |
| `fleet-pull` | fleet-pull-overview |
| `security` | acs-operator, kairos |
| `mesh` | servicemesh, rhcl, hub-gateway, service-interconnect |
| `observability` | grafana, kiali, kafka-console, kubecost |
| `workshop` | developer-hub, showroom, gitea |
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

Regenerate layout after legacy sync:

```bash
python scripts/generate-vp-values.py
python scripts/apply-vp-argo-layout.py
```
