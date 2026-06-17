# Architecture diagrams

Source diagrams for GitHub Pages and the [Validated Patterns](https://validatedpatterns.io) doc set.

## Files

| Source | Published image | Used in |
|--------|-----------------|---------|
| `hybrid-mesh-overview.mmd` | `arch-hybrid-mesh-overview.png` | README, `architecture.md` |
| (existing) | `arch-hub-spoke-flow.png` | `architecture.md` |
| (existing) | `arch-gitops-sync-sequence.png` | `architecture.md` |
| (existing) | `arch-sync-waves.png` | `architecture.md` |

## Regenerate PNG

```bash
cd docs/assets/images/diagrams
npx --yes @mermaid-js/mermaid-cli@11 -i hybrid-mesh-overview.mmd -o ../arch-hybrid-mesh-overview.png -b transparent
```
