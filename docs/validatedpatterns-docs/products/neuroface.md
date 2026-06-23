---
title: Neuroface
weight: 26
---

# NeuroFace

## What problem does it solve?

Workshop participants need a **multimodal AI demo** (webcam + LLM chat + PPE detection + object detection) without deploying a full custom vision pipeline. **NeuroFace** combines browser-based face analysis, **YOLO PPE serving** (hardhat, safety vest, goggles), **80-class object detection** (YOLOv4-tiny), and **MaaS** (`llama-scout-17b`) for contextual responses — one Route on the hub, integrated into Developer Hub and the Hybrid Mesh AI Workshop.

![NeuroFace Architecture](../../assets/images/neuroface-architecture.png)

| Item | Location |
|------|----------|
| Helm wrapper | `charts/all/neuroface/` |
| Upstream chart | [maximilianoPizarro/neuroface](https://github.com/maximilianoPizarro/neuroface) **v1.4.1** |
| YOLO PPE serving | KServe `InferenceService` **yolo-ppe-serving** (pre-built `neuroface-ppe-serving:v1.4.1`, KServe v1+v2) |
| PPE Workbench | OpenShift AI `Notebook` **ppe-workbench** + route `ppe-workbench.<hub-domain>` |
| PPE Retrain Workbench | OpenShift AI `Notebook` **ppe-retrain-workbench** + MinIO data connection |
| Route | `https://neuroface.<hub-domain>` (single Route — nginx proxies `/api/*` to backend) |
| Developer Hub | Component `demo-neuroface` in System `hybrid-mesh-shared-demos` |
| Showroom module | Module 27 — NeuroFace Computer Vision Journey |

**Not LibreChat:** workshop chat multimodal UX is NeuroFace only.

## Container images (v1.4.1)

| Image | Tag | Description |
|-------|-----|-------------|
| `quay.io/maximilianopizarro/neuroface-backend` | v1.4.1 | FastAPI + PPE data persistence + Kafka events |
| `quay.io/maximilianopizarro/neuroface-frontend` | v1.4.1 | Angular 17 + PPE UI + object detection + enhanced chat |
| `quay.io/maximilianopizarro/neuroface-ppe-serving` | v1.4.1 | Pre-built YOLOv8 PPE (KServe v1+v2, opencv-headless, ~60s cold start) |

## PPE Detection flow

![PPE Sequence](../../assets/images/neuroface-ppe-sequence.png)

The NeuroFace UI sends **base64 JSON** to `POST /api/ppe/detect`. Only the **frontend Route** (`neuroface.<hub-domain>`) is required:

```
Browser → Route neuroface → frontend nginx → backend /api/ppe/detect
  → hub-local yolo-ppe-serving InferenceService (KServe v1 /v1/predict)
```

**Do not** create extra OpenShift Routes that bypass the backend (e.g. `/api/ppe/v1/predict` → YOLO directly). YOLO expects **raw JPEG binary**, not base64 JSON — the backend handles the conversion.

## AI Chat flow

![AI Chat](../../assets/images/neuroface-chat-flow.png)

## Face Recognition flow

![Face Recognition](../../assets/images/neuroface-face-flow.png)

## Object Detection flow (80 COCO classes)

![Object Detection](../../assets/images/neuroface-object-flow.png)

## Training flow

![Training](../../assets/images/neuroface-training-flow.png)

## UI Screenshots

| Chat & PPE analysis | Object detection | Face recognition |
|---|---|---|
| ![Chat](../../assets/images/neuroface-chat.png) | ![Objects](../../assets/images/neuroface-objects.png) | ![Recognition](../../assets/images/neuroface-recognition.png) |

## GitOps automation (fresh install)

| PostSync / chart | Purpose |
| ---------------- | ------- |
| `minio-ppe-model-seed` | Uploads `best.pt` to `s3://models/ppe-detection/model/` (hub MinIO) |
| `yolo-ppe-serving` | KServe `ServingRuntime` + `InferenceService` (pre-built image, MinIO model) |
| `ppe-workbench` | Jupyter Notebook CR + `ppe-detection.ipynb` for image PPE lab |
| `ppe-retrain-workbench` | Jupyter Notebook CR + MinIO env for retraining workflows |
| `neuroface-maas-key-sync` | Wires `NEUROFACE_CHAT_API_KEY` from `neuroface-maas-api-key`; copies from `kairos-ai-credentials` if placeholder |
| RHDP `litemaas.apiKey` | Clustergroup propagates key to `neuroface.chat.apiKey` (preferred on RHDP) |

## MaaS API keys

Preferred: **Vault + ExternalSecret** — see [Vault & External Secrets](vault.md).

RHDP: inject `litemaas.apiKey` in field-content / clustergroup values.

Day-2 fallback:

```bash
export MAAS_KEY_LLAMA='sk-...'
oc create secret generic maas-facilitator-seed -n vault --from-literal=api-key='sk-...'
```

## Verify

```bash
curl -sk "https://neuroface.<hub-domain>/api/ppe/status"    # reachable: true
curl -sk "https://ppe-workbench.<hub-domain>/"              # 200 when notebook pod running
oc get inferenceservice yolo-ppe-serving -n neuroface       # READY True
curl -sk -X POST "https://neuroface.<hub-domain>/api/chat" \
  -H 'Content-Type: application/json' -d '{"message":"hello"}'
```

## Troubleshooting

| Symptom | Fix |
| ------- | --- |
| PPE not enabled | Chart `neuroface.ppe.enabled: true`; check `InferenceService/yolo-ppe-serving` **Ready** |
| PPE status unreachable | Wait ~60s for model load on predictor pod; check `oc logs -l component=predictor -n neuroface` |
| PPE detects 0 persons (webcam active) | Remove stray Routes pointing `/api/ppe/*` directly to YOLO; use frontend→backend path only |
| Workbench 503 | Start **ppe-workbench** in OpenShift AI → Workbenches |
| Chat **401** | `maas-facilitator-seed` or RHDP `litemaas.apiKey`; PostSync `neuroface-maas-key-sync` |
| Backend CrashLoop | Orphan deploy in `default` — use namespace `neuroface` only |
| InferenceService not Ready | Confirm `aws-connection-ppe-models` secret and MinIO seed job completed |

Workshop content: [Hybrid Mesh AI Workshop](../workshop/index.md).

**Related:** [OpenShift AI](openshift-ai.md) · [Vault](vault.md)

## Computer Vision Journey (hub-and-spoke)

The **NeuroFace CV** journey federates PPE inference across east and west spokes — similar in spirit to Industrial Edge hub-gateway load balancing, but dedicated to computer vision.

| Item | Location |
|------|----------|
| Hub gateway chart | `charts/all/neuroface-gateway/` |
| Spoke inference chart | `charts/all/spoke-neuroface-cv/` |
| Public Route | `https://neuroface-cv.<hub-domain>` |
| HTTPRoute split | 50% east / 50% west → `yolo-ppe-serving` via Skupper |
| Mesh mode | Gateway: **sidecar** (`neuroface-gateway-system`); spokes: **ambient** on `neuroface-cv` |
| OTel tracing | Mesh default → `cluster-collector` → Tempo |
| Grafana dashboard | **NeuroFace CV — Participants** (`uid: neuroface-cv`) |
| Developer Hub | System `neuroface-cv-journey` (components `neuroface-gateway`, `edge-ppe-east`, `edge-ppe-west`) |
| Showroom helpers | `neuroface-cv-status`, `neuroface-cv-traffic` |

### Architecture

1. **Hub** — `neuroface-gateway` (Gateway API) exposes `neuroface-cv.<hub>` with weighted `HTTPRoute` to Skupper listeners `neuroface-cv-east` / `neuroface-cv-west`.
2. **Spokes** — `spoke-neuroface-cv` deploys KServe `InferenceService` **yolo-ppe-serving** in namespace `neuroface-cv` (ambient mesh, `istio.io/dataplane-mode: none` on predictor pods) with HPA (min 1, max 4, CPU 70%).
3. **Skupper** — Connectors on each spoke publish `yolo-ppe-serving:8080`; hub listeners bridge into `neuroface-gateway-system` ExternalName services.
4. **Model storage** — Hub MinIO seeds `best.pt`; spokes reach MinIO via Skupper `minio-hub`; ODH DataConnection secret `aws-connection-ppe-models`.

### Verify

```bash
curl -sk "https://neuroface-cv.<hub-domain>/api/ppe/status"
curl -sk "https://neuroface-cv.<hub-domain>/health"
curl -sk "https://neuroface-cv.<hub-domain>/v2/models/yolo-ppe/ready"  # KServe v2
bash scripts/verify-neuroface-cv.sh
oc get httproute -n neuroface-gateway-system
oc get inferenceservice yolo-ppe-serving -n neuroface-cv   # on east/west spokes
for i in $(seq 1 20); do curl -sk "https://neuroface-cv.<hub-domain>/health"; done
```

### Troubleshooting

| Symptom | Fix |
| ------- | --- |
| CV route 503 | Check `neuroface-gateway-istio` endpoints; Istio gateway pod must be Programmed |
| `/api/ppe/status` 502 | Skupper listeners/connectors missing; verify `oc get listener,connector -n service-interconnect \| grep neuroface-cv` |
| One spoke never receives traffic | HTTPRoute weights; confirm both `clusters.east.domain` and `clusters.west.domain` on hub |
| PPE pod not ready on spoke | Model download from MinIO ~30s; check predictor pod logs |
| No Grafana metrics | `istio-monitoring` PodMonitor in `neuroface-gateway-system` and `neuroface-cv` (spokes); allow ~2 min after first traffic |
| No Tempo traces | Confirm `Telemetry/mesh-default` and OTel collector in `openshift-opentelemetry` |
