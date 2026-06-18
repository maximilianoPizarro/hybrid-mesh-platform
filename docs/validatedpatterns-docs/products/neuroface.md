---
title: Neuroface
weight: 26
---

# NeuroFace

## What problem does it solve?

Workshop participants need a **multimodal AI demo** (webcam + LLM chat + PPE detection) without deploying a full custom vision pipeline. **NeuroFace** combines browser-based face analysis, **YOLO PPE serving** (hardhat, safety vest, goggles), and **MaaS** (`llama-scout-17b`) for contextual responses — one Route on the hub, integrated into Developer Hub and the Hybrid Mesh AI Workshop.

![NeuroFace UI](../../assets/images/neuroface.png)

| Item | Location |
|------|----------|
| Helm wrapper | `charts/all/neuroface/` |
| Upstream chart | [maximilianoPizarro/neuroface](https://github.com/maximilianoPizarro/neuroface) **v1.3.0** |
| YOLO PPE serving | In-cluster `yolo-ppe-serving` (CPU torch, HuggingFace model) |
| PPE Workbench | OpenShift AI `Notebook` **ppe-workbench** + route `ppe-workbench.<hub-domain>` |
| Route | `https://neuroface.<hub-domain>` |
| Developer Hub | Component `demo-neuroface` in System `hybrid-mesh-shared-demos` |
| Showroom module | Parte B module 25 |

**Not LibreChat:** workshop chat multimodal UX is NeuroFace only.

## GitOps automation (fresh install)

| PostSync / chart | Purpose |
| ---------------- | ------- |
| `yolo-ppe-serving` | YOLO model download + FastAPI on port 8080 (`replicas: 1`) |
| `ppe-workbench` | Jupyter Notebook CR + `ppe-detection.ipynb` for image PPE lab |
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
oc get deploy yolo-ppe-serving -n neuroface                # READY 1/1
curl -sk -X POST "https://neuroface.<hub-domain>/api/chat" \
  -H 'Content-Type: application/json' -d '{"message":"hello"}'
```

## Troubleshooting

| Symptom | Fix |
| ------- | --- |
| PPE not enabled | Chart `neuroface.ppe.enabled: true`; check `yolo-ppe-serving` pod **replicas: 1** |
| PPE status unreachable | Scale `yolo-ppe-serving` to 1; wait ~3–5 min for pip + model load |
| Workbench 503 | Start **ppe-workbench** in OpenShift AI → Workbenches |
| Chat **401** | `maas-facilitator-seed` or RHDP `litemaas.apiKey`; PostSync `neuroface-maas-key-sync` |
| Backend CrashLoop | Orphan deploy in `default` — use namespace `neuroface` only |
| PVC Multi-Attach | Scale backend `0→1`: `oc scale deploy/neuroface-backend -n neuroface --replicas=0 && sleep 10 && oc scale --replicas=1` |

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
| Mesh mode | **Sidecar** (`istio.io/dataplane-mode: none` on `neuroface-gateway-system`) |
| Grafana dashboard | **NeuroFace CV — Participants** (`uid: neuroface-cv`) |
| Developer Hub | System `neuroface-cv-journey` (components `neuroface-gateway`, `edge-ppe-east`, `edge-ppe-west`) |
| Showroom helpers | `neuroface-cv-status`, `neuroface-cv-traffic` |

### Architecture

1. **Hub** — `neuroface-gateway` (Gateway API) exposes `neuroface-cv.<hub>` with weighted `HTTPRoute` to Skupper listeners `neuroface-cv-east` / `neuroface-cv-west`.
2. **Spokes** — `spoke-neuroface-cv` deploys `yolo-ppe-serving` in namespace `neuroface-cv` with HPA (min 1, max 4, CPU 70%).
3. **Skupper** — Connectors on each spoke publish `yolo-ppe-serving:8080`; hub listeners bridge into `neuroface-gateway-system` ExternalName services.

The main NeuroFace UI remains at `https://neuroface.<hub-domain>`; the CV gateway is inference-only (`/health`, `/v1/predict`, `/api/ppe/status`).

### Verify

```bash
curl -sk "https://neuroface-cv.<hub-domain>/api/ppe/status"
curl -sk "https://neuroface-cv.<hub-domain>/health"
bash scripts/verify-neuroface-cv.sh
oc get httproute -n neuroface-gateway-system
oc get deploy yolo-ppe-serving -n neuroface-cv   # on east/west spokes
```

### Troubleshooting

| Symptom | Fix |
| ------- | --- |
| CV route 503 | Check `neuroface-gateway-istio` endpoints; Istio gateway pod must be Programmed |
| `/api/ppe/status` 502 | Skupper listeners/connectors missing; verify `oc get listener,connector -n service-interconnect \| grep neuroface-cv` |
| One spoke never receives traffic | HTTPRoute weights; confirm both `clusters.east.domain` and `clusters.west.domain` on hub |
| PPE pod not ready on spoke | YOLO model download + pip install ~3–5 min; check `oc logs deploy/yolo-ppe-serving -n neuroface-cv` |
| No Grafana metrics | `istio-monitoring` PodMonitor in `neuroface-gateway-system`; allow ~2 min after first traffic |
