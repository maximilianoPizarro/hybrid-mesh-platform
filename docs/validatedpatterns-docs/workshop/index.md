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
| **Part B — Hands-on** | 10–28 | `userN` lab | Fleet → IE → mesh → GitOps → Vault/ESO → AI stack → operator apps |
| **Facilitator** | 29 (not in nav), 30 | Agents / facilitators | Full-stack verification · AI show-and-tell script |

AI track order: **30** (facilitator) → **Vault & External Secrets** (after module 20) → **22** OpenShift AI → **23** AI Gateway → **24** MCP → **25** LLM/RAG → **26** Predictive → **27** NeuroFace → **28** End-user apps.

## Hero screenshots (Gemini + manual overrides)

Workshop heroes are **Gemini-generated diagrams** (Red Hat branding) under `docs/assets/images/workshop/`. Architecture PNGs under `docs/assets/images/arch-*.png` use the same style. Baseline commit: **`8d41c0d`**.

| Step | Command / file |
| ---- | -------------- |
| Restore Gemini heroes | `git checkout 8d41c0d -- docs/assets/images/workshop/ docs/assets/images/arch-*.png` |
| Keep manual edits | `18`, `20`, `23`, `24`, `30` — re-copy after restore; also keep `19-openshift-virtualization`, `22-openshift-ia-stack`, `26-text-ai-predictive` from `HEAD` |
| Optional live capture | `npm install && npm run capture:workshop` (`package.json`; `node_modules/` gitignored) |
| Manifest (live URLs) | `scripts/workshop-screenshot-manifest.yaml` |
| Sync → showroom | `SHOWROOM_DIR=../showroom-hybrid-mesh-ai bash scripts/sync-showroom-content.sh` |
| Rollout in cluster | `oc rollout restart deployment/showroom -n showroom` |

### Preserve rules

- **Manual overrides** — never overwrite from Gemini without intent: `18-scalability`, `20-acs-kuadrant`, `23-ai-gateway`, `24-mcp-gateway`, `30-ai-show-and-tell`.
- **`03-security-scale-hybrid.png`** — ACS Central (may match `20` unless manually edited).
- **CNV module 19** — live Dev Hub template capture when KubeVirt CR is unavailable.

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

Refresh Argo app `hub-post-install-bootstrap` when the showroom app never synced (503 on showroom route).

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
- [Vault & External Secrets](../products/vault.md) · [Developer Hub](../products/developer-hub.md) · [OpenShift AI](../products/openshift-ai.md) · [NeuroFace](../products/neuroface.md)

**Next →** [Getting Started](../getting-started.md) · [Install improvements](../install-improvements.md)
