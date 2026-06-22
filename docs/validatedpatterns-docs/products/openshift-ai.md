---
title: Openshift Ai
weight: 27
---

# OpenShift AI

## What problem does it solve?

Workshop and Industrial Edge teams need **model serving**, **notebooks/workbenches**, and **external LLM access** without standing up inference infrastructure per user. On the **hub**, OpenShift AI (RHODS) provisions **DataScienceCluster**, per-user namespaces (`ai-user1`…), and **MaaS proxies** to RHDP LiteMaaS. On **spokes**, a lighter **RawDeployment** KServe stack scores anomaly models against Kafka telemetry.

**NeuroFace** (OVMS PPE Safety webcam) and **Developer Hub Lightspeed** use MaaS models (`llama-scout-17b`, `granite-3-2-8b-instruct`).

## Hub component

| Path | Purpose |
|------|---------|
| `charts/all/openshift-ai-hub/` | `DataScienceCluster`, per-user `ai-userN` + notebook `neuroface-ml-lab`, `maas-workshop`, MaaS proxies |
| `charts/all/developer-hub/templates/catalog-openshift-ai.yaml` | Catalog System `openshift-ai-workshop` — one Component per user |

## Per-user projects (userN)

| Pattern | Description |
|---------|-------------|
| Namespace | `ai-user1` … `ai-user50` (`opendatahub.io/dashboard: "true"`) |
| RBAC | `userN` → `admin` on `ai-userN` |
| Workbench | Notebook **`neuroface-ml-lab`** — microp learning + MaaS chat lab |
| MaaS | Secret `maas-connection` per project |
| Shared | `maas-workshop` — playground + MaaS InferenceService proxies |

### How to reach your project (userN)

1. OpenShift Console → **OpenShift AI** (Platform Hub-Spoke menu)  
   Or: `https://rh-ai.apps.<hub-domain>`
2. **Applications** → **Enabled** → ensure dashboard is enabled
3. **Data Science Projects** → select **`ai-userN`** (matches workshop login `userN`)
4. **Workbenches** → start **`neuroface-ml-lab`**
5. Cross-link: **NeuroFace** UI at `https://neuroface.<hub-domain>` for OVMS **face-detection-retail-0005** (PPE Safety webcam)

Developer Hub: **Catalog** → System **openshift-ai-workshop** → Component **`ai-userN`**.

## Model serving (hub workshop track)

| Component | DSC setting (chart default) |
|-----------|----------------------------|
| Workbenches | `workbenches.managementState: Managed` |
| KServe | `RawDeployment` — MaaS proxy InferenceServices in `maas-workshop` |
| ModelMesh / Serverless | **Optional** — disabled by default (see below) |

### Do I need OpenShift Serverless for KServe?

**No**, for this pattern’s default. OpenShift AI 3.x + KServe can run in **`RawDeployment`** mode (`modelServing.defaultDeploymentMode: RawDeployment`, `kserve.serving.managementState: Removed`). InferenceServices deploy as normal Deployments — no Knative, no `KnativeServing` CR.

Install **OpenShift Serverless** only if you explicitly enable `modelServing.serverlessEnabled: true` (Knative-based autoscaling / scale-to-zero). The hub chart still lists `serverless-operator` in subscriptions for optional use; KServe on the hub does **not** depend on it with current values.

### CPU models on MinIO (automated)

| Step | Chart | What happens |
|------|-------|----------------|
| 1 | `industrial-edge-minio` | MinIO + bucket `models` (+ `quay`, `kubecost`) |
| 2 | `industrial-edge-minio` PostSync | Job `minio-model-seed` uploads CPU sklearn model to `s3://models/anomaly-detection/model/` |
| 3 | `openshift-ai-hub` | Secret `aws-connection-models` in `maas-workshop` and each `ai-userN` (OpenShift AI dashboard S3 connection) |
| 4 | `openshift-ai-hub` | InferenceService `workshop-sklearn` (KServe RawDeployment) reads the MinIO model |

Spokes reach the same bucket via Skupper `minio-hub` (`http://minio-hub.service-interconnect.svc:9000`) — see `industrial-edge-data-science-project`.

**Console:** `https://minio-console-industrial-edge-ml-workspace.<hub-apps-domain>` — browse/upload CPU model artifacts to bucket `models`.

## MaaS models (external)

Endpoint: `https://maas-rhdp.apps.maas.redhatworkshops.io/v1` — keys via RHDP `litemaas.apiKey` or Secret `maas-facilitator-seed` (Vault+ESO).

| Model | Use case |
|-------|----------|
| `llama-scout-17b` | Default userN / NeuroFace chat |
| `granite-3-2-8b-instruct` | Developer Hub Lightspeed |
| `deepseek-r1-distill-qwen-14b` | Optional ODS connection |
| `codellama-7b-instruct` | Code / templates |

## Console

- **ConsoleLink:** Platform Hub-Spoke → OpenShift AI
- URL: `https://rh-ai.apps.<hub-apps-domain>`
- **Legacy (2.x):** `https://rhods-dashboard-redhat-ods-applications.<hub-apps-domain>/` — OpenShift AI 3.4 operator redirects to `rh-ai.apps.*`; bookmarks may still use the old hostname during transition.

## Developer Hub

- Catalog: **openshift-ai-workshop** / **maas-workshop-shared**
- Kuadrant LLM API: `/kuadrant` → workshop MaaS API Product

## Documentation

- [Red Hat OpenShift AI documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai/)
