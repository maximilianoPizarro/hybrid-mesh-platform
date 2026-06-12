---
title: Quay
weight: 30
---

# Quay Registry

**Git path:** `charts/all/quay-registry/`
{: .fs-3 .text-grey-dk-000 }

Red Hat **Quay** is the enterprise container registry on the **hub**. This platform uses Quay for workshop image metadata, optional mirror workflows, and catalog annotations — not as the default Tekton push target for Industrial Edge pipelines.

## What ships

| Resource | Purpose |
| -------- | ------- |
| `QuayRegistry` CR | Registry + Clair + builder (hub) |
| MinIO / RadosGW | Object storage backend for image layers |
| PostSync Job `quay-workshop-org-setup` | Creates org `workshop`, push robot, dockerconfig secrets |
| Route | `https://quay-registry.<hub-domain>` |

## Workshop org setup

The PostSync job in [`charts/all/quay-registry/templates/quay-org-setup.yaml`](https://github.com/maximilianoPizarro/hybrid-mesh-platform/tree/main/charts/all/quay-registry/templates/quay-org-setup.yaml) runs Python from [`files/setup.py`](https://github.com/maximilianoPizarro/hybrid-mesh-platform/tree/main/charts/all/quay-registry/files/setup.py):

1. Waits for Quay `/api/v1/discovery` (not `/version`, which redirects)
2. Authenticates with bearer token (`QUAY_ADMIN_TOKEN`) or admin password
3. Creates org `workshop` and robot `workshop-push` idempotently
4. Writes `quay-workshop-push` secrets to `quay-registry`, `developer-hub`, and `openshift-gitops`

## Operator discovery

Quay does **not** enroll workloads via namespace annotations. Catalog entities reference Quay with:

```yaml
annotations:
  quay.io/repository-slug: workshop/<uniqueName>
```

Pipelines use the internal OpenShift image registry by default; Quay slug is metadata for the Developer Hub Quay card when enabled.

## Verify

```bash
oc get quayregistry -n quay-registry
oc get job quay-workshop-org-setup -n quay-registry
oc get secret quay-workshop-push -n developer-hub
curl -sk "https://quay-registry.<hub-domain>/api/v1/discovery" | head
```

## Troubleshooting

| Symptom | Fix |
| ------- | --- |
| Job CrashLoop on `/version` | Use `/discovery` endpoint (fixed in `setup.py`) |
| Robot create 400 | Job GETs existing robot before POST |
| Secret missing in `openshift-gitops` | RBAC RoleBinding for `quay-org-setup` SA on that namespace |

## Documentation

- [Red Hat Quay documentation](https://docs.redhat.com/en/documentation/red_hat_quay/)

**Next:** [Developer Hub](developer-hub.md) for catalog Quay annotations and scaffolding.
