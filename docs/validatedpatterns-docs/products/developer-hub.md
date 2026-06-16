---
title: Developer Hub
weight: 21
---

# Developer Hub

**Git path:** `charts/all/developer-hub/`
{: .fs-3 .text-grey-dk-000 }

## What problem does it solve?

Operators juggling ACM, Argo CD, three OpenShift consoles, and scattered README files lack a **single entry point** for developers and workshop participants. **Developer Hub (RHDH)** is Backstage with Red Hat plugins: catalog entities for every workload, **software templates** that scaffold Camel routes and AI workspaces, **Topology** across hub/east/west, and **Tekton** pipeline visibility.

In this pattern RHDH lives on the **hub** (`developer-hub` namespace, AppProject `workshop`). Templates under `docs/assets/backstage/software-templates/` create Industrial Edge integrations, OpenShift AI workspaces, and CNV VMs — each wired to the correct spoke via catalog annotations (`backstage.io/kubernetes-cluster`).

Red Hat **Developer Hub** (RHDH) is the enterprise distribution of [Backstage](https://backstage.io/). On this platform it is the **single pane of glass** for Industrial Edge: catalog, scaffolding, multi-cluster topology, Tekton CI, and OCM fleet overview.

## Plugins enabled on this platform

| Plugin | Tab / area | Purpose |
| ------ | ---------- | ------- |
| **OCM** | **Clusters** menu, `/ocm` | Managed cluster health (east/west) |
| **Kubernetes** | Kubernetes | Pods, deployments, events per cluster |
| **Topology** | Topology | Workload graph (requires `kubernetes-cluster` annotation) |
| **Tekton** | CI | PipelineRuns (`janus-idp.io/tekton` annotation) |
| **Scaffolder** | Create | Software templates (GitHub `blob` catalog URL) |
| **Notifications** | Bell icon | In-app alerts after scaffold/delete |
| **TechDocs** | Docs | Onboarding mkdocs mounted in-pod (`catalog-onboarding.yaml`) |
| **Argo CD** | Argo CD | Read-only app view when `plugins.argocd.enabled` |
| **Adoption Insights** | Insights | Events read (RBAC CSV) |
| **Lightspeed** | `/lightspeed` | Granite vLLM via Llama Stack + LCS sidecars (same model as Kairos) |
| **Kuadrant** | `/kuadrant` | API Products, **Request API key**, My API Keys (`plugins.kuadrant.enabled: true`) |
| **RBAC** | Permission framework | CSV at `files/lightspeed/rbac-policy.csv` — **not** tied to Lightspeed enable |
| **Keycloak catalog** | Users/Groups | Sync from Keycloak `backstage` realm |

Disabled or optional: Kafka, ACS security-insights (package missing in RHDH 1.9 image).

## Authentication (Keycloak OIDC)

Sign-in uses **Keycloak**, not GitHub:

- Realm: `backstage` at `https://sso.<hub-apps-domain>`
- Client: `developer-hub`
- Secret: `developer-hub-oidc-auth` (`OIDC_CLIENT_SECRET`, `GITLAB_TOKEN`, `SESSION_SECRET`)
- Config split: `app-config-rhdh` + `app-config-auth-rhdh` (avoids YAML merge bugs on resolvers)

Platform users are defined in `charts/all/developer-hub/templates/catalog-users.yaml` (mounted as `/opt/app-root/src/users.yaml`).

## Industrial Edge catalog

The **Industrial Edge** system is registered from ConfigMap `developer-hub-catalog-ie`:

- **System**, **Domains** (hub, spoke-east, spoke-west)
- **Components** per spoke (sensors, Kafka, Camel, line-dashboard, etc.)
- **APIs** (MQTT, Kafka topics, S3 data lake)

Each spoke component includes:

```yaml
annotations:
  backstage.io/kubernetes-namespace: industrial-edge-tst-all
  backstage.io/kubernetes-id: line-dashboard          # when applicable
  backstage.io/kubernetes-cluster: east               # or west — required for Topology
  janus-idp.io/tekton: industrial-edge-ci             # CI tab for pipeline components
```

## Multi-cluster workload visibility

The Kubernetes plugin is configured for **hub**, **east**, and **west**:

1. **ManagedServiceAccount** `developer-hub` on each spoke (ACM)
2. **ClusterPermission** read-only on spoke APIs
3. **CronJob** syncs tokens → Secret `developer-hub-spoke-tokens`
4. Backstage reads `EAST_API_URL`, `EAST_SA_TOKEN`, `WEST_*` from that Secret

Without `backstage.io/kubernetes-cluster` on a catalog entity, Topology only queries the hub and shows no spoke deployments.

Verify:

```bash
oc get secret developer-hub-spoke-tokens -n developer-hub
oc get job -n developer-hub | grep spoke-token
```

## Scaffolding walkthrough (platformadmin)

1. Sign in to Developer Hub as **`platformadmin`** (catalog user + GitLab `ws-platformadmin` org).
2. **Create** → **Industrial Edge** → set **Target Cluster** to `east` or `west`.
3. After success, open the registered entity → **Topology** (spoke workloads) and **Kubernetes** (pods).
4. **Open in DevSpaces** link opens the GitLab repo in DevSpaces.
5. To remove: **Create** → **Industrial Edge Delete** with the same name and cluster.

See **[Scaffolding]({{ site.baseurl }}/scaffolding.html)** for prerequisites and troubleshooting.

## Contribution guide for this solution

If you are changing Developer Hub behavior (catalog, templates, topology, or scaffolder), follow the repository contribution checklist in [`CONTRIBUTING.md`](https://github.com/maximilianoPizarro/hybrid-mesh-platform/blob/main/CONTRIBUTING.md).

Focus points for this platform:

- keep both **Topology** and **Kubernetes** tabs working for Industrial Edge entities,
- validate full scaffolder flow (`fetch`, `publish`, `register`, ArgoCD create),
- use `catalogInfoPath: /catalog-info.yaml` in templates,
- keep GitLab bootstrap hook recreatable so `ws-<owner>` orgs exist for `publish:github`.

## Software templates

Templates are published as **GitHub Pages** static assets under `docs/assets/backstage/software-templates/`:

| Template | Description |
| -------- | ----------- |
| Industrial Edge | IoT instance on east/west → GitLab + ArgoCD + catalog |
| Camel Kaoto | Camel routes, DevSpaces, Continue AI |
| Industrial Edge Delete | Remove ArgoCD app + GitLab repo + notification |
| **CNV VM Workshop** | Hub KubeVirt VM → GitLab + catalog (+ optional Argo CD app) |
| **OpenShift AI Workspace** | Data Science project metadata on hub |

Catalog location (in `app-config-rhdh`):

```text
https://maximilianopizarro.github.io/hybrid-mesh-platform/assets/backstage/software-templates/templates-catalog.yaml
```

Scaffolding flow (after template run):

1. `fetch:template` — skeleton from GitHub Pages
2. `publish:github` — push to GitLab group `ws-<owner>`
3. `catalog:register` — entity in Developer Hub
4. `http:backstage:request` — create ArgoCD Application on spoke
5. `http:backstage:request` — notify owner

Entity links include **Source Code**, **Documentation** (GitLab README), and **Open in DevSpaces**.

### clusterDomain in templates

Use the **hub apps domain** including the `apps.` prefix, e.g. `apps.cluster-xqg4c.dynamic2.redhatworkshops.io`. This is used for Gitea, DevSpaces, and Developer Hub URLs in generated repos.

## Quay and container images

| Use | Image reference |
| --- | ----------------- |
| Pipeline build (Tekton buildah) | Internal OCP registry: `image-registry.openshift-image-registry.svc:5000/<namespace>/<app>:latest` |
| Deployment | Same internal image (no pull secret on OpenShift) |
| Public catalog label | `quay.io/maximilianopizarro/<uniqueName>` (metadata only) |

On-prem **Quay** (`charts/all/quay-registry/`) stores images in hub MinIO via `RadosGWStorage`. Scaffolding does **not** push to Quay by default — the build pipeline uses the internal registry; the Quay slug appears in catalog annotations for discovery.

Quay push credentials are optional on the hub (`quayDockerConfigJson` via Helm `--set`, never committed). Helper: `scripts/generate-quay-dockerconfig.sh`.

## GitLab and app-of-apps org

| Org | Created by | Use |
| --- | ---------- | --- |
| `ws-<user>` | `gitlab-workshop-bootstrap` PostSync Job | Scaffolder `publish:github` repos |
| `app-of-apps` | same Job | ApplicationSet GitLab generator repos — delete repo → ArgoCD prune |

GitLab route: `https://gitlab.apps.<hub-apps-domain>`. Integration token: `GITLAB_TOKEN` in `developer-hub-oidc-auth`.

## Proxies for scaffolder

| Proxy | Purpose |
| ----- | ------- |
| `/api/proxy/gitlab` | Delete GitLab projects |
| `/api/proxy/k8s-api` | Create/delete ArgoCD Applications |

## Deployment components

| Resource | Purpose |
| -------- | ------- |
| `Backstage` CR | RHDH operator workload |
| `app-config-rhdh` | Catalog, kubernetes, OCM, integrations, proxy |
| `app-config-auth-rhdh` | OIDC auth |
| `dynamic-plugins-rhdh` | Plugin enable/disable |
| `managed-service-accounts.yaml` | Spoke SA for K8s plugin |
| `spoke-token-sync.yaml` | Token refresh CronJob |
| `hub-sa-token-secret.yaml` | Hub SA token for k8s-api proxy |

Route: `https://developer-hub.<hub-apps-domain>`

Continue AI for DevSpaces is provisioned on **spokes** via `charts/all/devspaces/templates/continue-ai-sync.yaml` — not on the hub.

## RBAC and Lightspeed (workshop)

With `plugins.rbac.enabled: true`, Backstage uses **deny-by-default**. The platform mounts `rbac-policy.csv` for all authenticated users (catalog, scaffolder, kubernetes, ocm, argocd, adoption-insights, techdocs, lightspeed). Admin policy user: `platformadmin`.

**Lightspeed** (`plugins.lightspeed.enabled`): API key syncs from `kairos-system/kairos-ai-credentials` (PostSync Job + ESO) or RHDP `litemaas.apiKey`.

**TechDocs:** `techdocs.builder: local` builds from entity repos (Gitea) on demand. Onboarding mkdocs lives under `files/onboarding/`; scaffolded entities include `mkdocs.yml` and `backstage.io/techdocs-ref: dir:.` in skeletons.

Rollout DevHub after Git merge: sync Argo app `field-content-developer-hub` on the hub.

## Kuadrant API keys (workshop)

Workshop users request keys in Developer Hub — no manual `oc` Secret creation.

1. Sign in as `user1`…`userN` or `platformadmin` (Keycloak).
2. **Option A:** **Kuadrant** sidebar → **API Products** → click the **product name** (not the pencil) → **Request API key** → choose plan (bronze/silver/gold).
3. **Option B:** **Catalog** → System **workshop-kuadrant-apis** → open an **API** entity → **Kuadrant** tab → **Request API key**.
4. Copy the key from **Kuadrant → My API Keys**.
5. Call gateways with `Authorization: APIKEY <key>`:

```bash
curl -H "Authorization: APIKEY $KEY" https://workshop-apis.<hub-apps-domain>/httpbin/get
curl -sk -H "Authorization: APIKEY $KEY" -H "Content-Type: application/json" \
  -X POST "https://ai-gateway.<hub-apps-domain>/v1/chat/completions" \
  -d '{"model":"granite-3-2-8b-instruct","messages":[{"role":"user","content":"Hello"}],"max_tokens":50}'
```

Post-install: Argo app `hub-post-install-bootstrap` PostSync Jobs + `bash scripts/verify-workshop-kuadrant-curl.sh` (set `KUADRANT_API_KEY`).

## Troubleshooting

| Symptom | Likely cause | Action |
| ------- | ------------- | ------ |
| `/ocm` 404 or “permission denied” | RBAC on; CSV missing OCM rules | Ensure `rbac-policy.csv` includes `ocm.*`; sync `rhdh-rbac-policy` ConfigMap |
| Topology / Adoption Insights denied | Same | Add `kubernetes.*`, `adoption-insights.*` to CSV (see skill) |
| No templates / empty catalog | Permissions or mount paths | Fix CSV + `extraFiles` mountPath; sync ArgoCD |
| `No integration found` for github.io | Missing integration host | Add `maximilianopizarro.github.io` under `integrations.github` |
| Topology shows hub only | Missing cluster annotation | Set `backstage.io/kubernetes-cluster: east\|west` |
| K8s plugin TLS errors | Self-signed API certs | `skipTLSVerify` + `NODE_TLS_REJECT_UNAUTHORIZED=0` |
| CI tab empty | Wrong Tekton annotation | `janus-idp.io/tekton: <namespace>` not `"true"` |
| IoT dashboard 503 from hub | Mesh on IE namespaces | Keep `industrial-edge-tst-all` and `spoke-gateway-system` **off** ambient mesh |
| Kuadrant API Products empty | K8s RBAC or CRD group | ClusterRole `developer-hub-kuadrant`: `devportal.kuadrant.io` apiproducts/apikeys + `gateway.networking.k8s.io` gateways/httproutes; sync `developer-hub` |
| Kuadrant create API key fails | Backstage permission or RBAC | `rbac-policy.csv`: `kuadrant.apikey.create`, `kuadrant.apikey.list`; routes `/kuadrant/api-products/...` |
| No **Request API key** / Kuadrant tab on API entities | Corrupt catalog ConfigMap (Helm `$var = replace` bug) | ConfigMap `developer-hub-catalog-workshop-kuadrant-apis` must contain full YAML (4× `kind: API`), not only the hub domain string; fixed in chart templates v1.5.1+ — re-sync `field-content-developer-hub` |
| Lightspeed chat 401 | Missing MaaS key | `maas-facilitator-seed` in `vault` or RHDP litemaas |
| TechDocs 404 for scaffolded app | Missing mkdocs in repo | Re-scaffold or add `mkdocs.yml` + `docs/index.md` to GitLab repo |

See also [Backstage assets README]({{ site.baseurl }}/assets/backstage/README.html) and the **developer-hub-scaffolder** Cursor skill.

## Links

- [Red Hat Developer Hub documentation](https://docs.redhat.com/en/documentation/red_hat_developer_hub/)
- [Backstage documentation](https://backstage.io/docs/)
- [test-drive-pe-oscg](https://github.com/maximilianoPizarro/test-drive-pe-oscg) — reference scaffolding pattern
