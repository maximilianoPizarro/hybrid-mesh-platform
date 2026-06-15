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
| Gitea deployment | Namespace `gitea` on hub (Helm subchart `gitea-chart` with `fullnameOverride: gitea`) |
| Route | `https://gitea-gitea.<hub-domain>` |
| PostSync `gitea-admin-setup` | Creates orgs `ws-user1` … `ws-userN`, admin org `ws-platformadmin` |
| PostSync `gitea-fix-app-ini` | Sets `ROOT_URL` / `PROTOCOL=http` on PVC from live cluster ingress domain |
| PostSync `gitea-fix-http-service` | Aligns `gitea-http` selector (subchart alias drift) and Route host |
| Integration token | `GITEA_TOKEN` in `developer-hub-oidc-auth` for scaffolder API |

Gitea listens on **HTTP** behind the OpenShift Route (TLS at the edge). `ROOT_URL` remains `https://gitea-gitea.<hub-domain>/`.

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
oc get job gitea-admin-setup gitea-fix-app-ini gitea-fix-http-service -n gitea
curl -skI "https://gitea-gitea.<hub-domain>/assets/js/index.js?v=1.25.4"   # expect HTTP 200
curl -sk "https://gitea-gitea.<hub-domain>/api/v1/version"
```

## Troubleshooting

| Symptom | Fix |
| ------- | --- |
| Assets / UI: *Failed to load asset files* | PostSync jobs should fix `ROOT_URL` and service selector; day-2: `bash scripts/apply-gitea-root-url.sh` |
| Scaffolder publish 404 | Confirm `ws-<owner>` org exists; re-run `gitea-admin-setup` |
| Template fetch fails | Catalog location must use GitHub `blob` URL for template root; skeleton paths are relative |
| Orphan Gitea in `default` | Never `helm apply` without `-n gitea`; delete orphan stack in `default` |

## Documentation

- [Gitea documentation](https://docs.gitea.com/)

**Next:** [Scaffolding](../scaffolding.md) for org naming and template catalog URL.
