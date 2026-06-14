---
title: Neuroface
weight: 26
---

# NeuroFace

## What problem does it solve?

Workshop participants need a **multimodal AI demo** (webcam + LLM chat) without deploying a full custom vision pipeline. **NeuroFace** combines face/object detection in the browser with **MaaS** (`llama-scout-17b`) for contextual responses — one Route on the hub, integrated into Developer Hub and the Hybrid Mesh AI Workshop.

Shared **Hybrid Mesh AI Workshop** demo for webcam face/object detection and contextual chat via MaaS (OpenAI-compatible API).

| Item | Location |
|------|----------|
| Helm wrapper | `charts/all/neuroface/` |
| Upstream chart | [maximilianoPizarro/neuroface](https://github.com/maximilianoPizarro/neuroface) v1.2.0 |
| Route | `https://neuroface.<hub-domain>` |
| Developer Hub | Component `demo-neuroface` in System `hybrid-mesh-shared-demos` |
| Showroom module | Parte B module 25 |

**Not LibreChat:** workshop chat multimodal UX is NeuroFace only.

Workshop content: [Hybrid Mesh AI Workshop](../workshop/index.md) (module *Vault & External Secrets* before AI track; module 27 — NeuroFace).

MaaS API keys should be sourced from **Vault** via **ExternalSecret** — see [Vault & External Secrets](vault.md). Facilitator day-2 fallback: `scripts/apply-maas-secrets.sh`.
