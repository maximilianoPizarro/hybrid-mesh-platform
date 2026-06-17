---
title: GitLab
weight: 23
---

# GitLab

**Git path:** `charts/all/gitlab-operator/`
{: .fs-3 .text-grey-dk-000 }

**GitLab** (GitLab Operator, standard profile) is the in-cluster SCM on the **hub**. Developer Hub scaffolder publishes projects here (via `publish:github` with GitLab host integration), GitLab Runner executes Tekton-related CI jobs, and DevSpaces clones from GitLab on the hub while workspaces run on spokes.

## What ships

| Resource | Purpose |
| -------- | ------- |
| GitLab Operator | Subscription `gitlab-operator-kubernetes` (community-operators, channel `stable`) |
| GitLab CR | Namespace `gitlab` — webservice, gitaly, PostgreSQL, Container Registry |
| GitLab Runner Operator | Subscription in `gitlab-runner`; Runner CR with tag `openshift` |
| Route | `https://gitlab.apps.<hub-domain>` |
| PostSync `gitlab-workshop-bootstrap` | Groups `ws-user1` … `ws-userN`, `developer-hub`, `app-of-apps`, `workshop-demos` |
| PostSync `gitlab-token-setup` | PAT → `GITLAB_TOKEN` in `developer-hub-oidc-auth` for scaffolder API |

Workshop users authenticate to GitLab with the same credentials as Developer Hub (Keycloak / `userN` / `Welcome123!`) until OmniAuth is fully wired.

## Scaffolder integration

Templates publish to:

```
gitlab.apps.<hub-domain>?owner=ws-<user>&repo=<name>-<targetCluster>
```

Developer Hub proxies GitLab for delete and webhook actions at `/api/proxy/gitlab`.

## Operator discovery

GitLab is deployed via OLM operators. Catalog entities reference source with:

```yaml
annotations:
  backstage.io/source-location: url:https://gitlab.apps.<hub-domain>/ws-<user>/<repo>
```

## Verify

```bash
oc get gitlab -n gitlab
oc get runners -n gitlab-runner
oc get route -n gitlab
curl -skI "https://gitlab.apps.<hub-domain>/"
curl -sk -H "PRIVATE-TOKEN: <token>" "https://gitlab.apps.<hub-domain>/api/v4/version"
```

## Troubleshooting

| Symptom | Fix |
| ------- | --- |
| GitLab pods Pending | Hub undersized — use **4×16/64** workers; check PVC storage class |
| Argo `gitlab-operator` SyncFailed on `GitLab` CR | Expected until GitLab Operator CSV installs (`SkipDryRunOnMissingResource` on CR); subscriptions sync at wave 2 |
| Scaffolder publish 404 | Confirm `ws-<owner>` group exists; re-run `gitlab-workshop-bootstrap` |
| Runner not picking jobs | Check `gitlab-runner-token` Secret and Runner CR tags include `openshift` |
| `GITLAB_TOKEN` invalid | Re-run PostSync `gitlab-token-setup` in `developer-hub` (skips with exit 0 if GitLab not deployed yet) |

## Documentation

- [GitLab Operator on OpenShift](https://docs.gitlab.com/operator/)
- [GitLab Runner Operator](https://docs.gitlab.com/runner/install/operator/)

**Next:** [Scaffolding](../scaffolding.md) for group naming and template catalog URL.
