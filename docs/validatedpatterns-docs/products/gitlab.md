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
| GitLab Operator | Subscription `gitlab-operator-kubernetes` (community-operators, channel `stable`, **Automatic** InstallPlan) |
| GitLab CR | Namespace `gitlab` — chart **9.11.6**, webservice (min 3 / max **8**), gitaly, PostgreSQL, bundled MinIO, Container Registry |
| GitLab Runner | Controlled by `runnerEnabled: true/false` in values (default **false** if namespace `gitlab-runner` removed) |
| Route | `https://gitlab.apps.<hub-domain>` via `route-gitlab-apps.yaml` (canonical workshop URL) |
| **Istio Gateway** | `gitlab-gateway` in namespace `gitlab` — dedicated Gateway + HTTPRoute with LFS/upload 120s timeout and KAS WebSocket routing |
| Route (gateway) | `https://gitlab-gw.apps.<hub-domain>` — edge TLS → Istio gateway |
| PostSync `gitlab-workshop-bootstrap` | Groups `ws-user1` … `ws-userN`, `developer-hub`, `app-of-apps`, `workshop-demos` |
| PostSync `gitlab-token-setup` | PAT → `GITLAB_TOKEN` in `developer-hub-oidc-auth` for scaffolder API |

### Workshop scaling (for ~50 concurrent users)

| Component | min | max | CPU req/limit | Memory limit |
|-----------|-----|-----|--------------|--------------|
| webservice | 3 | **8** | 1 / 3 | 5 Gi |
| sidekiq | 2 | **6** | 500m / 2 | 4 Gi |
| gitlab-shell | 2 | **5** | — | — |

Override in `charts/all/gitlab-operator/values.yaml` under `gitlab.webservice`, `gitlab.sidekiq`, `gitlab.gitlabShell`.

### GitLab Runner (`runnerEnabled` flag)

Runner resources (OperatorGroup, Subscription, Runner CR, Role, RoleBinding) are all guarded by:

```yaml
# charts/all/gitlab-operator/values.yaml
runnerEnabled: false   # set true to enable (namespace gitlab-runner must exist first)
```

Bootstrap job also skips the `gitlab-runner-token` secret when the namespace is absent.

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

## Kairos SmartScalingPolicies for GitLab

Four `SmartScalingPolicy` CRs in `kairos-system` (label `kairos.io/policy-type: workshop-platform`) make GitLab resources visible in the Kairos Console UI and auto-tune resources under workshop load:

| Policy | Target | Trigger |
|--------|--------|---------|
| `gitlab-webservice-workshop` | webservice | CPU >75% → +30% (max 3), mem >80% → +25% (max 5Gi) |
| `gitlab-sidekiq-workshop` | sidekiq | CPU >70% → +50% (max 2), mem >85% → +20% (max 4Gi) |
| `gitlab-kas-workshop` | kas | CPU >60% → +25% |
| `gitlab-registry-workshop` | registry | CPU >70% → +30%, mem >80% → +20% |

Policies are defined in `charts/all/kairos/templates/gitlab-scaling-policies.yaml`.

## Dedicated Istio Gateway

`charts/all/gitlab-operator/templates/gitlab-gateway.yaml` creates an Istio mesh entrypoint for GitLab:

```
[user] → OpenShift Route (edge TLS) → gitlab-gateway-istio (ClusterIP)
       → HTTPRoute → gitlab-webservice-default:8080
```

HTTPRoute rules:
- `/info/lfs`, `/upload` → webservice (120s timeout for Git LFS and large pushes)
- `/-/kubernetes` → gitlab-kas:8154 (KAS WebSocket for DevSpaces)
- `/` → webservice (60s default)

The canonical `gitlab-apps` Route is still present for direct route access. The gateway route `gitlab-gw.apps.*` adds Istio observability.

## Troubleshooting

| Symptom | Fix |
| ------- | --- |
| GitLab pods Pending | Hub undersized — use **4×16/64** workers; check PVC storage class |
| `ConfigError` object storage / `connection` empty | Chart enables bundled MinIO (`global.minio.enabled: true`); do not disable MinIO without external S3 |
| Route 503 but pods Running | Operator route is `gitlab-gitlab.apps.*`; workshop URL is `gitlab.apps.*` — confirm `route/gitlab-apps` exists |
| Argo `gitlab-operator` SyncFailed on `GitLab` CR | Expected until GitLab Operator CSV installs (`SkipDryRunOnMissingResource` on CR); subscriptions sync at wave 2 |
| Argo `gitlab-operator` Missing (Runner resources) | `gitlab-runner` namespace missing — set `runnerEnabled: false` in values; remove stuck finalizer: `oc patch runner.apps.gitlab.com gitlab-runner -n gitlab-runner --type json -p '[{"op":"remove","path":"/metadata/finalizers"}]'` |
| Argo operation stuck on `Subscription/gitlab-runner-operator` | Terminate: `oc patch application gitlab-operator -n openshift-gitops --type merge -p '{"operation":null}'` then re-sync |
| InstallPlan **Manual** / operator never installs | `values.yaml` sets `installPlanApproval: Automatic` for both GitLab subscriptions |
| Scaffolder publish 404 | Confirm `ws-<owner>` group exists; re-run `gitlab-workshop-bootstrap` |
| Bootstrap fails with Forbidden on `gitlab-runner-token` | `gitlab-runner` namespace missing — already guarded with namespace check in chart; delete old failed job pods |
| Runner not picking jobs | Check `gitlab-runner-token` Secret and Runner CR tags include `openshift` |
| `GITLAB_TOKEN` invalid | Re-run PostSync `gitlab-token-setup` in `developer-hub` (skips with exit 0 if GitLab not deployed yet) |

## Documentation

- [GitLab Operator on OpenShift](https://docs.gitlab.com/operator/)
- [GitLab Runner Operator](https://docs.gitlab.com/runner/install/operator/)

**Next:** [Scaffolding](../scaffolding.md) for group naming and template catalog URL.
