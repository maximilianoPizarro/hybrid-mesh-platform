# Hybrid Mesh Platform

Validated Patterns implementation of the Hybrid Mesh hub-spoke platform (forked from [multicloud-gitops](https://github.com/validatedpatterns/multicloud-gitops)).

**Legacy repo (frozen):** [platform-hub-spoke-config](https://github.com/maximilianoPizarro/platform-hub-spoke-config)  
**Workshop Showroom (unchanged):** [showroom-hybrid-mesh-ai](https://github.com/maximilianoPizarro/showroom-hybrid-mesh-ai)

## What's included

- ACM fleet (east/west spokes) via `charts/all/acm-hub-spoke`
- Ambient OpenShift Service Mesh, Skupper Service Interconnect, RHCL/Kuadrant
- Industrial Edge factory stack on spokes
- OpenShift AI, Developer Hub, ACS, observability, Kairos, NeuroFace, Showroom

See [MIGRATION.md](MIGRATION.md) for architecture differences vs the legacy App-of-Apps layout.

## Quick start

```bash
cp values-secret.yaml.template values-secret.yaml
# Edit values-secret.yaml with Vault paths or generated secrets

./pattern.sh install
```

Cluster groups:

| Values file | Cluster |
|-------------|---------|
| `values-hub.yaml` | Hub |
| `values-east.yaml` | East spoke |
| `values-west.yaml` | West spoke |

Regenerate values from legacy source (read-only):

```bash
python scripts/generate-vp-values.py
```

## Verification

```bash
./scripts/verify-fleet.sh
```

## Documentation

- [Validated Patterns — Hybrid Mesh Platform](https://validatedpatterns.io/patterns/hybrid-mesh-platform/) (after docs PR merge)
- [Implementation requirements](https://validatedpatterns.io/contribute/implementation/)
