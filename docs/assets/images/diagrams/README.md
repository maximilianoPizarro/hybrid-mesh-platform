# Architecture diagrams

Source diagrams for GitHub Pages and the [Validated Patterns](https://validatedpatterns.io) doc set.

## Files

| Source | Published image | Used in |
|--------|-----------------|---------|
| `hybrid-mesh-overview.mmd` | `arch-hybrid-mesh-overview.png` | README, `architecture.md` |
| (existing) | `arch-hub-spoke-flow.png` | `architecture.md` |
| (existing) | `arch-gitops-sync-sequence.png` | `architecture.md` |
| (existing) | `arch-sync-waves.png` | `architecture.md` |

## Regenerate PNG (local)

```bash
cd docs/assets/images/diagrams
npx --yes @mermaid-js/mermaid-cli@11 -i hybrid-mesh-overview.mmd -o ../arch-hybrid-mesh-overview.png -b transparent
```

## Stylized exports (Gemini)

For workshop slides or validatedpatterns.io hero images, use **Gemini** (image model) with:

- Input: the `.mmd` file or existing `arch-hub-spoke-flow.png`
- Prompt: *"Technical architecture diagram, dark theme, Red Hat OpenShift style. Hub cluster with ACM and Argo CD at center; east and west spokes; PUSH arrows from ApplicationSet; PULL clustergroup on each spoke; Skupper mesh between clusters. Label: Hybrid Mesh Platform — Validated Patterns. No marketing fluff."*

Save output as `arch-hybrid-mesh-overview-gemini.png` if you need a raster variant; keep `.mmd` as the source of truth in Git.
