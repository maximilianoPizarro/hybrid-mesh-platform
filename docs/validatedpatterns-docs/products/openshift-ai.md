---
title: Openshift Ai
weight: 27
---

# OpenShift AI

Red Hat **OpenShift AI** on the **hub** provides dashboard, workbenches, **ModelMesh** (multi-model), **Knative/Serverless** (via `serverless-operator`), KServe, and MaaS-backed external models for the workshop.

## Hub component

| Path | Purpose |
|------|---------|
| `charts/all/openshift-ai-hub/` | `DataScienceCluster`, per-user `ai-userN` projects, `maas-workshop`, MaaS proxies |
| `charts/all/operators/` | `serverless-operator` (hub) + `rhods-operator` |
| `charts/all/developer-hub/templates/catalog-openshift-ai.yaml` | Catalog System `openshift-ai-workshop` — one Component per user |

## Per-user projects

| Pattern | Description |
|---------|-------------|
| Namespace | `ai-user1` … `ai-user50` (label `opendatahub.io/dashboard: "true"`) |
| RBAC | `userN` → `admin` on `ai-userN` |
| Developer Hub | Component `ai-userN` owned by `userN` in System `openshift-ai-workshop` |
| MaaS | Secret `openshift-ai-maas-credentials` in each project (same `OPENAI_API_BASE`) |
| ModelMesh ISVC | `workshop-sklearn` — sklearn example from hub MinIO (`anomaly-detection/model`) |

## Model serving (hub workshop track)

| Component | DSC setting |
|-----------|-------------|
| ModelMesh | `modelmeshserving.managementState: Managed` |
| Knative / Serverless | `kserve.serving.managementState: Managed` + `serverless-operator` subscription |
| Default ISVC mode | `defaultDeploymentMode: ModelMesh` (MaaS proxies in `maas-workshop` stay `RawDeployment`) |

Spokes keep **RawDeployment** only (`charts/all/industrial-edge-data-science-cluster/`).

## MaaS models (external)

Models are proxied from `https://maas-rhdp.apps.maas.redhatworkshops.io/v1` — API keys via RHDP `litemaas.apiKey` or Secret `openshift-ai-maas-credentials` (never Git).

| Model | Use case |
|-------|----------|
| `llama-scout-17b` | Default workshop / Lightspeed / userN |
| `deepseek-r1-distill-qwen-14b` | Admin reasoning / GitOps reconciliation |
| `codellama-7b-instruct` | Code / scaffolder / templates |

## Console

- **ConsoleLink:** Platform Hub-Spoke → OpenShift AI
- URL: `https://rhods-dashboard-redhat-ods-applications.<hub-apps-domain>`

## Developer Hub

- Software template: **OpenShift AI: Data Science Workspace**
- MCP: Developer Hub MCP tools + OpenShift AI playground config in `maas-workshop`

## Documentation

- [Red Hat OpenShift AI documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai/)
