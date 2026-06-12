---
title: Gitea
weight: 23
---

# Gitea

**Git path:** `charts/all/gitea/`
{: .fs-3 .text-grey-dk-000 }

**Gitea** is the in-cluster Git server on the **hub**. Developer Hub scaffolder publishes repositories here (via `publish:github` action configured for Gitea), and DevSpaces clones from Gitea on the hub while workspaces run on spokes.

## What ships

| Resource | Purpose |
| -------- | ------- |
| Gitea deployment | Namespace `gitea` on hub |
| Route | `https://gitea-gitea.<hub-domain>` |
| PostSync `gitea-admin-setup` | Creates orgs `ws-user1` … `ws-userN`, admin org `ws-platformadmin` |
| Integration token | `GITEA_TOKEN` in `developer-hub-oidc-auth` for scaffolder API |

Workshop users authenticate to Gitea with the same credentials as Developer Hub (Keycloak / `userN` / `Welcome123!`).

## Scaffolder integration

Templates publish to:

```
gitea-gitea.<hub-domain>?owner=ws-<user>&repo=<name>-<targetCluster>
```

Developer Hub proxies Gitea for delete and webhook actions at `/api/proxy/gitea`.

## Operator discovery

Gitea is not an OpenShift operator workload in catalog Topology. Entities reference source with:

```yaml
annotations:
  backstage.io/source-location: url:https://gitea-gitea.<hub-domain>/ws-<user>/<repo>
```

## Verify

```bash
oc get route gitea -n gitea
oc get job gitea-admin-setup -n gitea
curl -sk "https://gitea-gitea.<hub-domain>/api/v1/version"
```

## Troubleshooting

| Symptom | Fix |
| ------- | --- |
| Scaffolder publish 404 | Confirm `ws-<owner>` org exists; re-run `gitea-admin-setup` |
| Template fetch fails | Catalog location must use GitHub `blob` URL for template root; skeleton paths are relative |

## Documentation

- [Gitea documentation](https://docs.gitea.com/)

**Next:** [Scaffolding](../scaffolding.md) for org naming and template catalog URL.
