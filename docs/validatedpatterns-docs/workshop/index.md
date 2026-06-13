---
title: Hybrid Mesh AI Workshop
parent: Hybrid Mesh Platform
nav_order: 50
---

# Hybrid Mesh AI Workshop

Antora lab guide deployed on the hub as **Showroom** — separate content repo, GitOps-managed routes, live cluster heroes.

| Resource | URL |
| -------- | --- |
| **Showroom (learners)** | `https://showroom-showroom.apps.<hub-domain>/` |
| **Registration** | `https://workshop-registration.apps.<hub-domain>/` |
| **Content repo** | [showroom-hybrid-mesh-ai](https://github.com/maximilianoPizarro/showroom-hybrid-mesh-ai) |
| **Platform GitOps** | [hybrid-mesh-platform](https://github.com/maximilianoPizarro/hybrid-mesh-platform) |
| **Cursor skill (content)** | `showroom-hybrid-mesh-ai/.cursor/skills/hybrid-mesh-ai-workshop/SKILL.md` |

Charts: `charts/all/showroom`, `charts/all/workshop-registration`, `charts/all/workshop-demos` (hub sync waves 4–7).

## Module map

| Part | Modules | Audience | Narrative hook |
| ---- | ------- | -------- | -------------- |
| Welcome | index | All | Hub-spoke architecture + component map |
| **Part A — Strategy** | 01–05 | Executive / show-and-tell | Hybrid cloud → ROSA → security → AWS AI → customer journey |
| **Part B — Hands-on** | 10–28 | `userN` lab | Fleet → IE → mesh → GitOps → AI stack → operator apps |
| **Facilitator** | 29 (not in nav), 30 | Agents / facilitators | Full-stack verification · AI show-and-tell script |

AI track order: **30** (facilitator) → **22** OpenShift AI → **23** AI Gateway → **24** MCP → **25** LLM/RAG → **26** Predictive → **27** NeuroFace → **28** End-user apps.

## Hero screenshots (live cluster only)

Hero PNGs are **real product captures** from the hub UI — not generated diagrams. Sources live in this repo under `docs/assets/images/workshop/` and architecture PNGs under `docs/assets/images/`.

| Step | Command / file |
| ---- | -------------- |
| Manifest (URL per hero) | `scripts/workshop-screenshot-manifest.yaml` |
| Batch capture (Playwright) | `node scripts/capture-workshop-screenshots.mjs` |
| Normalize width 960px | `bash scripts/normalize-workshop-screenshots.sh` (ImageMagick on Linux/macOS) |
| Sync → showroom repo | `SHOWROOM_DIR=../showroom-hybrid-mesh-ai bash scripts/sync-showroom-content.sh` |
| Rollout in cluster | `oc rollout restart deployment/showroom -n showroom` |

### Preserve rules

- **`03-security-scale-hybrid.png`** and **`20-acs-kuadrant.png`** — keep existing ACS Central captures (`preserve: true` in manifest). Do not overwrite during batch runs.
- **CNV module 19** — if KubeVirt CRD is missing on the hub, hero = Developer Hub Self-service → *OpenShift Virtualization: Workshop VM* template.

### Narrative-aligned heroes (maintainer checklist)

| Module | Hero should show |
| ------ | ---------------- |
| 05 Cases & roadmap | Kafka Console multicluster (`dev/factory/prod × east/west`) — IoT journey milestone |
| 13 Industrial Edge | ManuELA Realtime Data — `pump-1` temperature/vibration charts |
| 26 Predictive AI | Mailpit IE vibration anomaly inbox |
| 29 Verification (facilitator) | Argo CD Applications Healthy/Synced |
| 20 ACS + Kuadrant | ACS hero preserved; add inline Kuadrant/Dev Hub image in `.adoc` if dual story needed |

Run `md5sum docs/assets/images/workshop/*.png | sort` and dedupe module heroes before sync — only **03 = 20** (ACS) should duplicate among Part B heroes.

## Publish content changes

### 1. Platform repo (images + scripts)

```bash
# After updating PNGs or scripts/workshop-screenshot-manifest.yaml
SHOWROOM_DIR=../showroom-hybrid-mesh-ai bash scripts/sync-showroom-content.sh
git add docs/assets/images/ scripts/
git commit -m "docs: workshop hero screenshots and sync manifest"
git push origin main
```

### 2. Showroom repo (Antora `.adoc`)

```bash
cd ../showroom-hybrid-mesh-ai
git add content/
git commit -m "content: workshop module updates"
git push origin main
```

The hub **git-cloner** sidecar pulls `showroom-hybrid-mesh-ai` on pod start. Force refresh:

```bash
oc rollout restart deployment/showroom -n showroom
oc rollout status deployment/showroom -n showroom --timeout=120s
```

Or run `bash scripts/apply-workshop-showroom.sh` when the Argo app never synced (503 on showroom route).

## Verify workshop surfaces

```bash
oc login --token=<token> --server=<hub-api-url>

bash scripts/verify-workshop-http200.sh
bash scripts/verify-workshop-e2e.sh   # optional deep check

curl -sk -o /dev/null -w '%{http_code}\n' \
  https://workshop-registration.apps.<hub-domain>/api/health
curl -sk -o /dev/null -w '%{http_code}\n' \
  https://showroom-showroom.apps.<hub-domain>/
```

Facilitator smoke test:

1. Register at **workshop-registration** → redirect to Showroom with `USER_NAME=user1`.
2. Open **Terminal** tab — embedded console links must reload after switching browser tabs (`workshop-runtime.js`).
3. Spot-check heroes: modules **13** (Realtime Data), **20** (ACS intact), **26** (Mailpit), **29** (Argo CD tiles).

## Showroom UX (terminal multi-tab)

Supplemental UI in the showroom repo:

- `content/supplemental-ui/js/workshop-runtime.js` — `visibilitychange` / `pagehide` reload for embedded iframes; `blankFrame()` for `_blank` quick links.
- `content/supplemental-ui/partials/header-content.hbs` — Terminal drawer tooltip.

## Related docs

- [Getting Started — Workshop section](../getting-started.md#hybrid-mesh-ai-workshop-hub)
- [RHDP install playbook](../install-improvements.md) — registration, showroom, day-2 scripts
- [Validation Guide](../../validation-guide.md) — optional showroom apps
- [Developer Hub](../products/developer-hub.md) · [OpenShift AI](../products/openshift-ai.md) · [NeuroFace](../products/neuroface.md)

**Next →** [Getting Started](../getting-started.md) · [Install improvements](../install-improvements.md)
